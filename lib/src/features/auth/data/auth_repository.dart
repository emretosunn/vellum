import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

/// Supabase Auth + Profiles repository
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  // ─── Auth ─────────────────────────────────────────

  /// Mevcut oturum
  Session? get currentSession => _client.auth.currentSession;

  /// Mevcut kullanıcı
  User? get currentUser => _client.auth.currentUser;

  /// Auth state değişikliklerini dinle
  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  /// E-posta ile kayıt ol
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    return response;
  }

  /// E-posta ile giriş yap
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Çıkış yap
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Profile ──────────────────────────────────────

  /// Mevcut kullanıcının profilini al
  Future<Profile?> getCurrentProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final data =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Profili güncelle (username, bio, links, avatar_url, is_verified_author)
  Future<Profile> updateProfile({
    required String id,
    String? username,
    String? bio,
    List<Map<String, dynamic>>? links,
    String? avatarUrl,
    bool? isVerifiedAuthor,
  }) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (bio != null) updates['bio'] = bio;
    if (links != null) updates['links'] = links;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (isVerifiedAuthor != null) {
      updates['is_verified_author'] = isVerifiedAuthor;
    }

    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Profile.fromJson(data);
  }

  /// Avatar fotoğrafı yükle ve URL döndür
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
    required Uint8List fileBytes,
  }) async {
    final fileExt = filePath.split('.').last.toLowerCase();
    final storagePath = '$userId/avatar.$fileExt';

    await _client.storage.from('avatars').uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl =
        _client.storage.from('avatars').getPublicUrl(storagePath);
    return publicUrl;
  }

  /// Herhangi bir kullanıcının profilini ID ile al
  Future<Profile?> getProfileById(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Bildirim tercihlerini güncelle
  Future<void> updateNotificationPreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    await _client
        .from('profiles')
        .update({'notification_preferences': preferences})
        .eq('id', userId);
  }
}

// ─── Providers ────────────────────────────────────

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(supabaseClientProvider),
  );
});

/// Auth state stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Mevcut kullanıcı profili provider
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  // Auth state değişince profili tekrar al
  ref.watch(authStateProvider);
  return ref.read(authRepositoryProvider).getCurrentProfile();
});

/// Herhangi bir kullanıcının profili (family provider)
final profileByIdProvider =
    FutureProvider.family<Profile?, String>((ref, userId) async {
  return ref.read(authRepositoryProvider).getProfileById(userId);
});
