import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter.freezed.dart';
part 'chapter.g.dart';

/// Bölüm modeli.
@freezed
class Chapter with _$Chapter {
  const factory Chapter({
    required String id,
    @JsonKey(name: 'book_id') required String bookId,
    required String title,
    @Default(<String, dynamic>{}) Map<String, dynamic> content,
    @Default(10) int price,
    @Default(false) @JsonKey(name: 'is_free') bool isFree,
    @Default(0) @JsonKey(name: 'order') int order,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Chapter;

  factory Chapter.fromJson(Map<String, dynamic> json) =>
      _$ChapterFromJson(json);
}
