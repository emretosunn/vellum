// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookImpl _$$BookImplFromJson(Map<String, dynamic> json) => _$BookImpl(
  id: json['id'] as String,
  authorId: json['author_id'] as String,
  title: json['title'] as String,
  summary: json['summary'] as String? ?? '',
  coverImageUrl: json['cover_image_url'] as String?,
  status:
      $enumDecodeNullable(_$BookStatusEnumMap, json['status']) ??
      BookStatus.draft,
  totalEarnings: (json['total_earnings'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$BookImplToJson(_$BookImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author_id': instance.authorId,
      'title': instance.title,
      'summary': instance.summary,
      'cover_image_url': instance.coverImageUrl,
      'status': _$BookStatusEnumMap[instance.status]!,
      'total_earnings': instance.totalEarnings,
    };

const _$BookStatusEnumMap = {
  BookStatus.draft: 'draft',
  BookStatus.published: 'published',
  BookStatus.archived: 'archived',
};
