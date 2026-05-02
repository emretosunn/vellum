import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/env.dart';
import '../domain/profile.dart';

/// RPC `delete_my_account_cascade` cevabini parse eder (Map, Liste veya UTF-8 String).
Map<String, dynamic> _normalizeDeleteAccountRpcResult(dynamic raw) {
  if (raw == null) {
    return {'ok': false, 'error': 'null_response'};
  }

  dynamic candidate = raw;
  if (candidate is String && candidate.trim().isNotEmpty) {
    try {
      candidate = jsonDecode(candidate.trim());
    } catch (_) {
      return {'ok': false, 'error': 'invalid_response_string'};
    }
  }

  if (candidate is Map) {
    try {
      final m = Map<String, dynamic>.from(candidate);
      // Bazen PostgREST tek kolonlu jsonb doner: { "delete_my_account_cascade": { "ok": ... } }
      if (m.length == 1) {
        final inner = m.values.first;
        if (inner is Map) {
          return Map<String, dynamic>.from(inner);
        }
      }
      return m;
    } catch (_) {
      return {'ok': false, 'error': 'invalid_response_map'};
    }
  }
  if (candidate is List) {
    if (candidate.isEmpty) {
      return {'ok': false, 'error': 'empty_response'};
    }
    final first = candidate.first;
    if (first is Map) {
      return Map<String, dynamic>.from(first);
    }
  }

  return {
    'ok': false,
    'error': 'invalid_response_type',
    'type': raw.runtimeType.toString(),
  };
}

bool _deleteAccountRpcTruthyOk(dynamic ok) {
  if (ok == true || ok == 1) return true;
  if (ok is String) {
    final v = ok.trim().toLowerCase();
    return const {'true', '1', 't', 'yes'}.contains(v);
  }
  return false;
}

/// Supabase Auth + Profiles repository
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;
  static const String _cachedUsernameKey = 'cached_username';
  // go_router tarafındaki callback route'u ile birebir uyumlu tutulur.
  static const String _mobileAuthRedirect = 'vellum://auth/callback';

  LaunchMode _oauthLaunchModeForCurrentPlatform() {
    if (kIsWeb) return LaunchMode.platformDefault;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android'de de gerçek gömülü OAuth ekranı kullan.
        return LaunchMode.inAppWebView;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return LaunchMode.inAppWebView;
      default:
        return LaunchMode.platformDefault;
    }
  }

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

  /// Google ile giriş.
  ///
  /// Web: Supabase OAuth
  /// Android/iOS/macOS: Native Google Sign-In + signInWithIdToken
  Future<void> signInWithGoogleOAuth() async {
    if (kIsWeb) {
      await _signInWithGoogleOAuthWeb();
      return;
    }
    await _signInWithGoogleNative();
  }

  Future<void> _signInWithGoogleOAuthWeb() async {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/auth/callback'
        : _mobileAuthRedirect;
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: _oauthLaunchModeForCurrentPlatform(),
    );
  }

  Future<void> _signInWithGoogleOAuthEmbedded() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _mobileAuthRedirect,
      authScreenLaunchMode: _oauthLaunchModeForCurrentPlatform(),
    );
  }

  Future<void> _signInWithGoogleNative() async {
    final GoogleSignIn signIn = GoogleSignIn.instance;
    final useIosClient =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    await signIn.initialize(
      clientId: useIosClient ? Env.googleIosClientId : null,
      serverClientId: Env.googleWebClientId,
    );

    Future<void> authenticateOnce() async {
      final account = await signIn.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google kimlik jetonu alınamadı.');
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    }

    try {
      await authenticateOnce();
    } on GoogleSignInException catch (e) {
      final desc = (e.description ?? '').toLowerCase();
      final isFalseCancel = e.code == GoogleSignInExceptionCode.canceled &&
          desc.contains('activity is cancelled by the user');
      if (isFalseCancel) {
        // Bazı Android cihazlarda hesap seçimi sonrası yalancı "canceled" dönebiliyor.
        // Önce native'i bir kez daha deneyip, yine olursa gömülü OAuth fallback'e geç.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        try {
          await authenticateOnce();
          return;
        } on GoogleSignInException catch (e2) {
          final desc2 = (e2.description ?? '').toLowerCase();
          final stillFalseCancel =
              e2.code == GoogleSignInExceptionCode.canceled &&
              desc2.contains('activity is cancelled by the user');
          if (stillFalseCancel) {
            await _signInWithGoogleOAuthEmbedded();
            return;
          }
          throw Exception(
            'google_sign_in:${e2.code.name}:${e2.description ?? 'unknown'}',
          );
        }
      }
      throw Exception(
        'google_sign_in:${e.code.name}:${e.description ?? 'unknown'}',
      );
    }
  }

  /// Facebook OAuth ile giriş yap.
  Future<void> signInWithFacebookOAuth() async {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/auth/callback'
        : _mobileAuthRedirect;
    await _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: redirectTo,
      authScreenLaunchMode: _oauthLaunchModeForCurrentPlatform(),
    );
  }

  /// Apple ile giriş.
  ///
  /// iOS/macOS: yerel Sign in with Apple (Safari veya OAuth WebView açılmaz).
  /// Web: Supabase OAuth.
  Future<void> signInWithApple() async {
    if (kIsWeb) {
      await _signInWithAppleOAuth();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await _signInWithAppleNative();
      return;
    }
    throw UnsupportedError('Apple ile giriş bu platformda desteklenmiyor.');
  }

  Future<void> _signInWithAppleOAuth() async {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/auth/callback'
        : _mobileAuthRedirect;
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: redirectTo,
      authScreenLaunchMode: _oauthLaunchModeForCurrentPlatform(),
    );
  }

  Future<void> _signInWithAppleNative() async {
    final rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
        'Apple kimlik jetonu alınamadı.',
      );
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    if (credential.givenName != null || credential.familyName != null) {
      final parts = <String>[];
      final gn = credential.givenName?.trim();
      final fn = credential.familyName?.trim();
      if (gn != null && gn.isNotEmpty) parts.add(gn);
      if (fn != null && fn.isNotEmpty) parts.add(fn);
      final fullName = parts.join(' ');
      if (fullName.isNotEmpty) {
        await _client.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': fullName,
              if (credential.givenName != null)
                'given_name': credential.givenName,
              if (credential.familyName != null)
                'family_name': credential.familyName,
            },
          ),
        );
      }
    }
  }

  String _generateRawNonce() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
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

  /// Kullanıcının kendi hesabını ve ilişkili verilerini kalıcı olarak siler.
  /// Doğrulama için mevcut kullanıcı adını ister.
  Future<void> deleteMyAccountCascade({required String username}) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı');
    }

    await _removeMyAvatarStorageBestEffort(user.id);

    try {
      final result = await _client.rpc(
        'delete_my_account_cascade',
        params: {'p_username': username.trim()},
      );

      final map = _normalizeDeleteAccountRpcResult(result);

      final okVal = map['ok'];
      if (_deleteAccountRpcTruthyOk(okVal)) return;

      final err = map['error']?.toString().trim();
      if (kDebugMode) {
        debugPrint(
          'deleteMyAccountCascade: ok=$okVal error=${err ?? '(empty)'} raw=$result',
        );
      }
      throw Exception((err == null || err.isEmpty) ? 'unknown_error' : err);
    } on PostgrestException {
      rethrow;
    }
  }

  /// `avatars` bucket içinde `{userId}/...` yüklemelerini Storage API ile siler.
  /// Supabase'de `storage.objects` üzerine doğrudan SQL DELETE yasaktır.
  Future<void> _removeMyAvatarStorageBestEffort(String userId) async {
    try {
      final objects = await _client.storage.from('avatars').list(path: userId);
      if (objects.isEmpty) return;
      final paths = objects.map((f) => '$userId/${f.name}').toList();
      await _client.storage.from('avatars').remove(paths);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('avatars storage cleanup (ignored): $e\n$st');
      }
    }
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

  /// Kullanıcı adının kullanılabilir olup olmadığını kontrol eder.
  ///
  /// [excludeUserId] verilirse o kullanıcıya ait mevcut username "müsait" kabul edilir.
  Future<bool> isUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) async {
    final candidate = username.trim();
    if (candidate.isEmpty) return false;

    final data = await _client
        .from('profiles')
        .select('id, username')
        .ilike('username', candidate)
        .limit(10);

    final targetLower = candidate.toLowerCase();
    for (final row in data) {
      final map = row;
      final existingUsername = (map['username'] as String?)?.trim();
      if (existingUsername == null) continue;
      if (existingUsername.toLowerCase() != targetLower) continue;

      final existingId = map['id']?.toString();
      if (excludeUserId != null &&
          excludeUserId.isNotEmpty &&
          existingId == excludeUserId) {
        continue;
      }
      return false;
    }
    return true;
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

/// Mevcut kullanıcının profile satırı değiştiğinde event üretir.
final currentProfileRealtimeProvider = StreamProvider.autoDispose<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) {
    return Stream<int>.empty();
  }

  final controller = StreamController<int>.broadcast();
  final channel = client
      .channel('public:profiles:$uid')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: uid,
        ),
        callback: (_) {
          if (!controller.isClosed) {
            controller.add(DateTime.now().millisecondsSinceEpoch);
          }
        },
      )
      .subscribe();

  ref.onDispose(() async {
    await client.removeChannel(channel);
    await controller.close();
  });

  return controller.stream;
});
