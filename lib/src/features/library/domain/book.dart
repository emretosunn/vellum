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
    /// Kategori (Roman, Öykü, Korku vb.)
    String? category,
    /// 18+ içerik uyarısı; okurken onay istenir.
    @Default(false) @JsonKey(name: 'is_adult_18') bool isAdult18,
    /// İçerik uyarıları (cinsellik, şiddet vb.)
    @Default([]) @JsonKey(name: 'content_warnings') List<String> contentWarnings,
    /// Görüntülenme sayısı (detay sayfası açılışta artar)
    @Default(0) @JsonKey(name: 'view_count') int viewCount,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) =>
      _$BookFromJson(json);
}

/// Uygulama genelinde kullanılan kitap kategorileri.
const List<String> bookCategories = [
  'Korku',
  'Bilim Kurgu',
  'Tarih',
  'Kişisel Gelişim',
  'Çocuk',
  'Diğer',
];

/// İçerik uyarısı etiketleri (kitap oluştururken seçilebilir).
const List<String> contentWarningLabels = [
  'Cinsellik',
  'Şiddet',
  'Küfür',
  'Olgun temalar',
  'Diğer hassas içerik',
];
