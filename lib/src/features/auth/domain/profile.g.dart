// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileImpl _$$ProfileImplFromJson(
  Map<String, dynamic> json,
) => _$ProfileImpl(
  id: json['id'] as String,
  username: json['username'] as String,
  role: $enumDecodeNullable(_$UserRoleEnumMap, json['role']) ?? UserRole.reader,
  isPro: json['is_pro'] as bool? ?? false,
  subEndDate: json['sub_end_date'] == null
      ? null
      : DateTime.parse(json['sub_end_date'] as String),
  stripeCustomerId: json['stripe_customer_id'] as String?,
  isVerifiedAuthor: json['is_verified_author'] as bool? ?? false,
  isDeveloper: json['is_developer'] as bool? ?? false,
  avatarUrl: json['avatar_url'] as String?,
  bio: json['bio'] as String? ?? '',
  links:
      (_readLinks(json, 'links') as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const <Map<String, dynamic>>[],
  notificationPreferences:
      _readNotificationPreferences(json, 'notification_preferences')
          as Map<String, dynamic>? ??
      const <String, dynamic>{
        'newChapter': true,
        'comments': true,
        'bookLike': true,
        'reviews': true,
        'promotions': false,
        'weeklyDigest': true,
      },
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$ProfileImplToJson(_$ProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'role': _$UserRoleEnumMap[instance.role]!,
      'is_pro': instance.isPro,
      'sub_end_date': instance.subEndDate?.toIso8601String(),
      'stripe_customer_id': instance.stripeCustomerId,
      'is_verified_author': instance.isVerifiedAuthor,
      'is_developer': instance.isDeveloper,
      'avatar_url': instance.avatarUrl,
      'bio': instance.bio,
      'links': instance.links,
      'notification_preferences': instance.notificationPreferences,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.reader: 'reader',
  UserRole.author: 'author',
  UserRole.admin: 'admin',
};
