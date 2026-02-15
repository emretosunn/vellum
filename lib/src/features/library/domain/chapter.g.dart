// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChapterImpl _$$ChapterImplFromJson(Map<String, dynamic> json) =>
    _$ChapterImpl(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      title: json['title'] as String,
      content:
          json['content'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      price: (json['price'] as num?)?.toInt() ?? 10,
      isFree: json['is_free'] as bool? ?? false,
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$ChapterImplToJson(_$ChapterImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'book_id': instance.bookId,
      'title': instance.title,
      'content': instance.content,
      'price': instance.price,
      'is_free': instance.isFree,
      'order': instance.order,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
