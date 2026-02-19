import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';
part 'book.g.dart';

/// Kitap durum enum'u.
enum BookStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('published')
  published,
  @JsonValue('archived')
  archived,
}

/// Kitap modeli.
@freezed
class Book with _$Book {
  const factory Book({
    required String id,
    @JsonKey(name: 'author_id') required String authorId,
    required String title,
    @Default('') String summary,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    @Default(BookStatus.draft) BookStatus status,
    @Default(false) @JsonKey(name: 'is_published') bool isPublished,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) =>
      _$BookFromJson(json);
}
