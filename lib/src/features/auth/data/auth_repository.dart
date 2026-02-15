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
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
  }

  /// E-posta ile giriş yap
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
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

  /// Profili güncelle (username, role, is_verified_author)
  Future<Profile> updateProfile({
    required String id,
    String? username,
    bool? isVerifiedAuthor,
  }) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
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

  /// Yazar ol (is_verified_author → true, role → author)
  Future<Profile> becomeAuthor(String userId) async {
    final data = await _client
        .from('profiles')
        .update({
          'is_verified_author': true,
          'role': 'author',
        })
        .eq('id', userId)
        .select()
        .single();

    return Profile.fromJson(data);
  }
}

// ─── Providers ────────────────────────────────────

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
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
