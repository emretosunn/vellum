import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

/// Supabase Auth + Profiles repository
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;
  static const String _cachedUsernameKey = 'cached_username';
  // go_router tarafındaki callback route'u ile birebir uyumlu tutulur.
  static const String _mobileAuthRedirect = 'vellum://auth/callback';

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
    await _cacheUsername(username);
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

  /// Google OAuth ile giriş yap.
  ///
  /// Not: Web tarafında OAuth callback URL'lerinin Supabase dashboard'da doğru
  /// tanımlanması gerekir.
  Future<void> signInWithGoogleOAuth() async {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/auth/callback'
        : _mobileAuthRedirect;
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Facebook OAuth ile giriş yap.
  Future<void> signInWithFacebookOAuth() async {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/auth/callback'
        : _mobileAuthRedirect;
    await _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: redirectTo,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Apple OAuth ile giriş yap.
  Future<void> signInWithAppleOAuth() async {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/auth/callback'
        : _mobileAuthRedirect;
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: redirectTo,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Uygulama içinden hesap silme talebi oluştur.
  /// Not: Gerçek silme işlemi backend/operasyon tarafından tamamlanır.
  Future<void> requestAccountDeletion({
    String reason = 'user_requested_in_app',
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı');
    }
    await _client.from('account_deletion_requests').insert({
      'user_id': user.id,
      'email': user.email,
      'reason': reason,
      'status': 'pending',
    });
  }

  // ─── Profile ──────────────────────────────────────

  /// Mevcut kullanıcının profilini al
  Future<Profile?> getCurrentProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    final profile = Profile.fromJson(data);
    await _cacheUsername(profile.username);
    return profile;
  }

  /// Profili güncelle (username, bio, links, avatar_url, is_verified_author)
  Future<Profile> updateProfile({
    required String id,
    String? username,
    String? bio,
    List<Map<String, dynamic>>? links,
    String? avatarUrl,
    bool? isVerifiedAuthor,
    bool? signupSetupCompleted,
    int? age,
    DateTime? birthDate,
  }) async {
    final updates = <String, dynamic>{};
    final trimmedUsername = username?.trim();
    if (trimmedUsername != null && trimmedUsername.isNotEmpty) {
      updates['username'] = trimmedUsername;
    }
    if (bio != null) updates['bio'] = bio;
    if (links != null) updates['links'] = links;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (isVerifiedAuthor != null) {
      updates['is_verified_author'] = isVerifiedAuthor;
    }
    if (signupSetupCompleted != null) {
      updates['signup_setup_completed'] = signupSetupCompleted;
    }
    if (age != null) updates['age'] = age;
    if (birthDate != null) {
      updates['birth_date'] = birthDate.toIso8601String().split('T').first;
    }

    if (updates.isEmpty) {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data != null) {
        return Profile.fromJson(data);
      }
      final user = currentUser;
      final fallbackUsername =
          trimmedUsername ??
          user?.userMetadata?['username']?.toString().trim() ??
          user?.email?.split('@').first ??
          'reader';
      final inserted = await _client
          .from('profiles')
          .upsert({'id': id, 'username': fallbackUsername}, onConflict: 'id')
          .select()
          .single();
      return Profile.fromJson(inserted);
    }

    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', id)
        .select()
        .maybeSingle();

    if (data == null) {
      final user = currentUser;
      final metadataUsername = user?.userMetadata?['username']
          ?.toString()
          .trim();
      final fallbackUsername =
          (updates['username'] as String?)?.trim().isNotEmpty == true
          ? updates['username'] as String
          : ((metadataUsername != null && metadataUsername.isNotEmpty)
                ? metadataUsername
                : (user?.email?.split('@').first ?? 'reader'));
      final upsertPayload = <String, dynamic>{
        'id': id,
        'username': fallbackUsername,
        ...updates,
      };
      final inserted = await _client
          .from('profiles')
          .upsert(upsertPayload, onConflict: 'id')
          .select()
          .single();
      final profile = Profile.fromJson(inserted);
      await _cacheUsername(profile.username);
      return profile;
    }

    final profile = Profile.fromJson(data);
    await _cacheUsername(profile.username);
    return profile;
  }

  /// Geliştirici panelinden başka kullanıcının Pro Yazar rozetini ayarla.
  /// RLS yüzünden direkt UPDATE çalışmadığı için Supabase RPC kullanır.
  Future<void> setVerifiedAuthor({
    required String targetUserId,
    required bool value,
  }) async {
    final res = await _client.rpc(
      'set_verified_author',
      params: {'_target_user_id': targetUserId, '_value': value},
    );
    final map = res as Map<String, dynamic>;
    if (map['ok'] != true) {
      final err = map['error'] as String? ?? 'unknown';
      throw Exception(err);
    }
  }

  /// Avatar fotoğrafı yükle ve URL döndür
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
    required Uint8List fileBytes,
  }) async {
    final fileExt = filePath.split('.').last.toLowerCase();
    final storagePath = '$userId/avatar.$fileExt';

    await _client.storage
        .from('avatars')
        .uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(storagePath);
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

  /// Kullanıcı adı arama (username üzerinden, tüm roller).
  /// Not: UI tarafında bu metot çeşitli yerlerde "yazar" araması için de
  /// kullanıldığı için isim korunuyor.
  Future<List<Profile>> searchAuthors(String query) async {
    if (query.trim().isEmpty) return [];

    final data = await _client
        .from('profiles')
        .select()
        .ilike('username', '%${query.trim()}%')
        .limit(20);

    return data.map<Profile>((json) => Profile.fromJson(json)).toList();
  }

  Future<void> _cacheUsername(String? username) async {
    final clean = username?.trim();
    if (clean == null || clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUsernameKey, clean);
  }

  Future<String?> getCachedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_cachedUsernameKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
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

final cachedUsernameProvider = FutureProvider<String?>((ref) async {
  return ref.read(authRepositoryProvider).getCachedUsername();
});

/// Herhangi bir kullanıcının profili (family provider)
final profileByIdProvider = FutureProvider.family<Profile?, String>((
  ref,
  userId,
) async {
  return ref.read(authRepositoryProvider).getProfileById(userId);
});
