// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Book _$BookFromJson(Map<String, dynamic> json) {
  return _Book.fromJson(json);
}

/// @nodoc
mixin _$Book {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_id')
  String get authorId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  @JsonKey(name: 'cover_image_url')
  String? get coverImageUrl => throw _privateConstructorUsedError;
  BookStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_published')
  bool get isPublished => throw _privateConstructorUsedError;

  /// Kategori (Roman, Öykü, Korku vb.)
  String? get category => throw _privateConstructorUsedError;

  /// 18+ içerik uyarısı; okurken onay istenir.
  @JsonKey(name: 'is_adult_18')
  bool get isAdult18 => throw _privateConstructorUsedError;

  /// İçerik uyarıları (cinsellik, şiddet vb.)
  @JsonKey(name: 'content_warnings')
  List<String> get contentWarnings => throw _privateConstructorUsedError;

  /// Görüntülenme sayısı (detay sayfası açılışta artar)
  @JsonKey(name: 'view_count')
  int get viewCount => throw _privateConstructorUsedError;

  /// Serializes this Book to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BookCopyWith<Book> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BookCopyWith<$Res> {
  factory $BookCopyWith(Book value, $Res Function(Book) then) =
      _$BookCopyWithImpl<$Res, Book>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'author_id') String authorId,
    String title,
    String summary,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    BookStatus status,
    @JsonKey(name: 'is_published') bool isPublished,
    String? category,
    @JsonKey(name: 'is_adult_18') bool isAdult18,
    @JsonKey(name: 'content_warnings') List<String> contentWarnings,
    @JsonKey(name: 'view_count') int viewCount,
  });
}

/// @nodoc
class _$BookCopyWithImpl<$Res, $Val extends Book>
    implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorId = null,
    Object? title = null,
    Object? summary = null,
    Object? coverImageUrl = freezed,
    Object? status = null,
    Object? isPublished = null,
    Object? category = freezed,
    Object? isAdult18 = null,
    Object? contentWarnings = null,
    Object? viewCount = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            authorId: null == authorId
                ? _value.authorId
                : authorId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String,
            coverImageUrl: freezed == coverImageUrl
                ? _value.coverImageUrl
                : coverImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as BookStatus,
            isPublished: null == isPublished
                ? _value.isPublished
                : isPublished // ignore: cast_nullable_to_non_nullable
                      as bool,
            category: freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String?,
            isAdult18: null == isAdult18
                ? _value.isAdult18
                : isAdult18 // ignore: cast_nullable_to_non_nullable
                      as bool,
            contentWarnings: null == contentWarnings
                ? _value.contentWarnings
                : contentWarnings // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            viewCount: null == viewCount
                ? _value.viewCount
                : viewCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BookImplCopyWith<$Res> implements $BookCopyWith<$Res> {
  factory _$$BookImplCopyWith(
    _$BookImpl value,
    $Res Function(_$BookImpl) then,
  ) = __$$BookImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'author_id') String authorId,
    String title,
    String summary,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    BookStatus status,
    @JsonKey(name: 'is_published') bool isPublished,
    String? category,
    @JsonKey(name: 'is_adult_18') bool isAdult18,
    @JsonKey(name: 'content_warnings') List<String> contentWarnings,
    @JsonKey(name: 'view_count') int viewCount,
  });
}

/// @nodoc
class __$$BookImplCopyWithImpl<$Res>
    extends _$BookCopyWithImpl<$Res, _$BookImpl>
    implements _$$BookImplCopyWith<$Res> {
  __$$BookImplCopyWithImpl(_$BookImpl _value, $Res Function(_$BookImpl) _then)
    : super(_value, _then);

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorId = null,
    Object? title = null,
    Object? summary = null,
    Object? coverImageUrl = freezed,
    Object? status = null,
    Object? isPublished = null,
    Object? category = freezed,
    Object? isAdult18 = null,
    Object? contentWarnings = null,
    Object? viewCount = null,
  }) {
    return _then(
      _$BookImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        authorId: null == authorId
            ? _value.authorId
            : authorId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String,
        coverImageUrl: freezed == coverImageUrl
            ? _value.coverImageUrl
            : coverImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as BookStatus,
        isPublished: null == isPublished
            ? _value.isPublished
            : isPublished // ignore: cast_nullable_to_non_nullable
                  as bool,
        category: freezed == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String?,
        isAdult18: null == isAdult18
            ? _value.isAdult18
            : isAdult18 // ignore: cast_nullable_to_non_nullable
                  as bool,
        contentWarnings: null == contentWarnings
            ? _value._contentWarnings
            : contentWarnings // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        viewCount: null == viewCount
            ? _value.viewCount
            : viewCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BookImpl implements _Book {
  const _$BookImpl({
    required this.id,
    @JsonKey(name: 'author_id') required this.authorId,
    required this.title,
    this.summary = '',
    @JsonKey(name: 'cover_image_url') this.coverImageUrl,
    this.status = BookStatus.draft,
    @JsonKey(name: 'is_published') this.isPublished = false,
    this.category,
    @JsonKey(name: 'is_adult_18') this.isAdult18 = false,
    @JsonKey(name: 'content_warnings')
    final List<String> contentWarnings = const [],
    @JsonKey(name: 'view_count') this.viewCount = 0,
  }) : _contentWarnings = contentWarnings;

  factory _$BookImpl.fromJson(Map<String, dynamic> json) =>
      _$$BookImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'author_id')
  final String authorId;
  @override
  final String title;
  @override
  @JsonKey()
  final String summary;
  @override
  @JsonKey(name: 'cover_image_url')
  final String? coverImageUrl;
  @override
  @JsonKey()
  final BookStatus status;
  @override
  @JsonKey(name: 'is_published')
  final bool isPublished;

  /// Kategori (Roman, Öykü, Korku vb.)
  @override
  final String? category;

  /// 18+ içerik uyarısı; okurken onay istenir.
  @override
  @JsonKey(name: 'is_adult_18')
  final bool isAdult18;

  /// İçerik uyarıları (cinsellik, şiddet vb.)
  final List<String> _contentWarnings;

  /// İçerik uyarıları (cinsellik, şiddet vb.)
  @override
  @JsonKey(name: 'content_warnings')
  List<String> get contentWarnings {
    if (_contentWarnings is EqualUnmodifiableListView) return _contentWarnings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_contentWarnings);
  }

  /// Görüntülenme sayısı (detay sayfası açılışta artar)
  @override
  @JsonKey(name: 'view_count')
  final int viewCount;

  @override
  String toString() {
    return 'Book(id: $id, authorId: $authorId, title: $title, summary: $summary, coverImageUrl: $coverImageUrl, status: $status, isPublished: $isPublished, category: $category, isAdult18: $isAdult18, contentWarnings: $contentWarnings, viewCount: $viewCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BookImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isPublished, isPublished) ||
                other.isPublished == isPublished) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.isAdult18, isAdult18) ||
                other.isAdult18 == isAdult18) &&
            const DeepCollectionEquality().equals(
              other._contentWarnings,
              _contentWarnings,
            ) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    authorId,
    title,
    summary,
    coverImageUrl,
    status,
    isPublished,
    category,
    isAdult18,
    const DeepCollectionEquality().hash(_contentWarnings),
    viewCount,
  );

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BookImplCopyWith<_$BookImpl> get copyWith =>
      __$$BookImplCopyWithImpl<_$BookImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BookImplToJson(this);
  }
}

abstract class _Book implements Book {
  const factory _Book({
    required final String id,
    @JsonKey(name: 'author_id') required final String authorId,
    required final String title,
    final String summary,
    @JsonKey(name: 'cover_image_url') final String? coverImageUrl,
    final BookStatus status,
    @JsonKey(name: 'is_published') final bool isPublished,
    final String? category,
    @JsonKey(name: 'is_adult_18') final bool isAdult18,
    @JsonKey(name: 'content_warnings') final List<String> contentWarnings,
    @JsonKey(name: 'view_count') final int viewCount,
  }) = _$BookImpl;

  factory _Book.fromJson(Map<String, dynamic> json) = _$BookImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'author_id')
  String get authorId;
  @override
  String get title;
  @override
  String get summary;
  @override
  @JsonKey(name: 'cover_image_url')
  String? get coverImageUrl;
  @override
  BookStatus get status;
  @override
  @JsonKey(name: 'is_published')
  bool get isPublished;

  /// Kategori (Roman, Öykü, Korku vb.)
  @override
  String? get category;

  /// 18+ içerik uyarısı; okurken onay istenir.
  @override
  @JsonKey(name: 'is_adult_18')
  bool get isAdult18;

  /// İçerik uyarıları (cinsellik, şiddet vb.)
  @override
  @JsonKey(name: 'content_warnings')
  List<String> get contentWarnings;

  /// Görüntülenme sayısı (detay sayfası açılışta artar)
  @override
  @JsonKey(name: 'view_count')
  int get viewCount;

  /// Create a copy of Book
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BookImplCopyWith<_$BookImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
