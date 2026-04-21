import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// Kullanıcı rolleri.
enum UserRole {
  @JsonValue('reader')
  reader,
  @JsonValue('author')
  author,
  @JsonValue('admin')
  admin,
}

/// Kullanıcı profil modeli.
@freezed
class Profile with _$Profile {
  const Profile._();

  const factory Profile({
    required String id,
    required String username,
    @Default(UserRole.reader) UserRole role,
    @Default(false) @JsonKey(name: 'is_pro') bool isPro,
    @JsonKey(name: 'sub_end_date') DateTime? subEndDate,
    @JsonKey(name: 'stripe_customer_id') String? stripeCustomerId,
    @Default(false) @JsonKey(name: 'is_verified_author') bool isVerifiedAuthor,
    @Default(false) @JsonKey(name: 'is_developer') bool isDeveloper,
    @Default(false)
    @JsonKey(name: 'signup_setup_completed')
    bool signupSetupCompleted,
    int? age,
    @JsonKey(name: 'birth_date') DateTime? birthDate,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @Default('') String bio,
    @Default(<Map<String, dynamic>>[])
    @JsonKey(readValue: _readLinks)
    List<Map<String, dynamic>> links,
    @Default(<String, dynamic>{
      'newChapter': true,
      'comments': true,
      'bookLike': true,
      'reviews': true,
      'promotions': false,
      'weeklyDigest': true,
    })
    @JsonKey(
      name: 'notification_preferences',
      readValue: _readNotificationPreferences,
    )
    Map<String, dynamic> notificationPreferences,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Profile;

  /// Abonelik aktif mi? (is_pro true VE bitiş tarihi gelecekte)
  bool get hasActiveSubscription {
    if (!isPro) return false;
    if (subEndDate == null) return isPro;
    return subEndDate!.isAfter(DateTime.now());
  }

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

/// null gelirse boş liste döndürür
Object? _readLinks(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return <Map<String, dynamic>>[];
  if (value is List) {
    return value
        .map((e) => (e as Map<dynamic, dynamic>)
            .map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
  return <Map<String, dynamic>>[];
}

const Map<String, dynamic> _defaultNotificationPreferences = {
  'newChapter': true,
  'comments': true,
  'bookLike': true,
  'reviews': true,
  'promotions': false,
  'weeklyDigest': true,
};

/// null gelirse default map; değilse backend'deki ile birleştirir (yeni anahtarlar varsayılan alır).
Object? _readNotificationPreferences(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return Map<String, dynamic>.from(_defaultNotificationPreferences);
  if (value is! Map) return Map<String, dynamic>.from(_defaultNotificationPreferences);
  final merged = Map<String, dynamic>.from(_defaultNotificationPreferences);
  for (final e in value.entries) {
    if (e.value is bool) merged[e.key.toString()] = e.value as bool;
  }
  return merged;
}
