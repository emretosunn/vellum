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
  tokenBalance: (json['token_balance'] as num?)?.toInt() ?? 0,
  isVerifiedAuthor: json['is_verified_author'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$ProfileImplToJson(_$ProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'role': _$UserRoleEnumMap[instance.role]!,
      'token_balance': instance.tokenBalance,
      'is_verified_author': instance.isVerifiedAuthor,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.reader: 'reader',
  UserRole.author: 'author',
  UserRole.admin: 'admin',
};
