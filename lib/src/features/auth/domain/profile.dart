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
  const factory Profile({
    required String id,
    required String username,
    @Default(UserRole.reader) UserRole role,
    @Default(0) @JsonKey(name: 'token_balance') int tokenBalance,
    @Default(false) @JsonKey(name: 'is_verified_author') bool isVerifiedAuthor,
    @Default(<String, dynamic>{
      'newChapter': true,
      'comments': true,
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

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

/// null gelirse default map döndürür
Object? _readNotificationPreferences(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return <String, dynamic>{
      'newChapter': true,
      'comments': true,
      'promotions': false,
      'weeklyDigest': true,
    };
  }
  return value;
}
