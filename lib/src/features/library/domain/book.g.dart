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
  isPublished: json['is_published'] as bool? ?? false,
  category: json['category'] as String?,
  isAdult18: json['is_adult_18'] as bool? ?? false,
  contentWarnings:
      (json['content_warnings'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$BookImplToJson(_$BookImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author_id': instance.authorId,
      'title': instance.title,
      'summary': instance.summary,
      'cover_image_url': instance.coverImageUrl,
      'status': _$BookStatusEnumMap[instance.status]!,
      'is_published': instance.isPublished,
      'category': instance.category,
      'is_adult_18': instance.isAdult18,
      'content_warnings': instance.contentWarnings,
      'view_count': instance.viewCount,
    };

const _$BookStatusEnumMap = {
  BookStatus.draft: 'draft',
  BookStatus.published: 'published',
  BookStatus.archived: 'archived',
};
