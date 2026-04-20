import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/profile.dart';
import '../domain/book.dart';

/// Sıralama türü (ana sayfa filtre)
enum BookSortOrder {
  recent,
  rating,
}

/// Kitap CRUD repository
class BookRepository {
  BookRepository(this._client);
  final SupabaseClient _client;

  /// Yayınlanan kitapları listele (vitrin) — sıralama ve kategori filtresi
  Future<List<Book>> getPublishedBooks({
    int limit = 20,
    int offset = 0,
    BookSortOrder sortOrder = BookSortOrder.recent,
    String? category,
    String? languageCode,
  }) async {
    final base = _client
        .from('books')
        .select()
        .eq('status', 'published');

    final filteredByLanguage = (languageCode != null && languageCode.isNotEmpty)
        ? base.eq('language_code', languageCode)
        : base;

    final filtered = (category != null && category.isNotEmpty)
        ? filteredByLanguage.eq('category', category)
        : filteredByLanguage;

    final data = await filtered
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    var books = data.map((json) => Book.fromJson(json)).toList();

    if (sortOrder == BookSortOrder.rating && books.isNotEmpty) {
      books = await _sortByRating(books);
    }

    return books;
  }

  /// Kitapları ortalama puana göre sıralar (reviews tablosundan)
  Future<List<Book>> _sortByRating(List<Book> books) async {
    if (books.isEmpty) return books;
    final bookIds = books.map((b) => b.id).toList();
    final reviewsData = await _client
        .from('reviews')
        .select('book_id, rating')
        .inFilter('book_id', bookIds);
    final Map<String, List<int>> byBook = {};
    for (final r in reviewsData) {
      final bid = r['book_id'] as String?;
      final rating = r['rating'] as int?;
      if (bid == null || rating == null) continue;
      byBook.putIfAbsent(bid, () => []).add(rating);
    }
    final Map<String, double> avgByBook = {};
    for (final e in byBook.entries) {
      final list = e.value;
      avgByBook[e.key] = list.reduce((a, b) => a + b) / list.length;
    }
    books.sort((a, b) {
      final avgA = avgByBook[a.id] ?? 0.0;
      final avgB = avgByBook[b.id] ?? 0.0;
      return avgB.compareTo(avgA);
    });
    return books;
  }

  /// Tek kitap detayı
  Future<Book?> getBookById(String bookId) async {
    final data =
        await _client.from('books').select().eq('id', bookId).maybeSingle();

    if (data == null) return null;
    return Book.fromJson(data);
  }

  /// Birden fazla kitabı ID listesine göre getirir (sıra korunur).
  Future<List<Book>> getBooksByIds(List<String> bookIds) async {
    if (bookIds.isEmpty) return [];
    final data = await _client
        .from('books')
        .select()
        .inFilter('id', bookIds);
    final byId = {for (final j in data) j['id'] as String: Book.fromJson(j)};
    return bookIds
        .map((id) => byId[id])
        .whereType<Book>()
        .toList();
  }

  /// Bir yazarın yayınlanmış kitapları
  Future<List<Book>> getPublishedBooksByAuthor(String authorId) async {
    final data = await _client
        .from('books')
        .select()
        .eq('author_id', authorId)
        .eq('status', 'published')
        .order('created_at', ascending: false);

    return data.map((json) => Book.fromJson(json)).toList();
  }

  /// Yazarın kendi kitapları
  Future<List<Book>> getMyBooks(String authorId) async {
    final data = await _client
        .from('books')
        .select()
        .eq('author_id', authorId)
        .order('updated_at', ascending: false);

    return data.map((json) => Book.fromJson(json)).toList();
  }

  /// Yeni kitap oluştur
  Future<Book> createBook({
    required String authorId,
    required String title,
    String summary = '',
    String? coverImageUrl,
    String? category,
    String? languageCode,
    bool isAdult18 = false,
    List<String> contentWarnings = const [],
  }) async {
    final data = await _client
        .from('books')
        .insert({
          'author_id': authorId,
          'title': title,
          'summary': summary,
          'cover_image_url': coverImageUrl,
          if (category != null && category.isNotEmpty) 'category': category,
          if (languageCode != null && languageCode.isNotEmpty)
            'language_code': languageCode,
          'is_adult_18': isAdult18,
          'content_warnings': contentWarnings,
        })
        .select()
        .single();

    return Book.fromJson(data);
  }

  /// Kitap güncelle
  Future<Book> updateBook({
    required String bookId,
    String? title,
    String? summary,
    String? coverImageUrl,
    String? status,
    String? category,
    String? languageCode,
    bool? isAdult18,
    List<String>? contentWarnings,
  }) async {
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (title != null) updates['title'] = title;
    if (summary != null) updates['summary'] = summary;
    if (coverImageUrl != null) updates['cover_image_url'] = coverImageUrl;
    if (status != null) updates['status'] = status;
    if (category != null) updates['category'] = category;
    if (languageCode != null) {
      updates['language_code'] = languageCode;
    }
    if (isAdult18 != null) updates['is_adult_18'] = isAdult18;
    if (contentWarnings != null) updates['content_warnings'] = contentWarnings;

    final data = await _client
        .from('books')
        .update(updates)
        .eq('id', bookId)
        .select()
        .single();

    return Book.fromJson(data);
  }

  /// Kitap sil
  /// Kitap arama (başlık veya özet üzerinden); kategori/sıra uygulanmaz
  Future<List<Book>> searchBooks(String query, {String? languageCode}) async {
    var q = _client
        .from('books')
        .select()
        .eq('status', 'published')
        .or('title.ilike.%$query%,summary.ilike.%$query%');

    if (languageCode != null && languageCode.isNotEmpty) {
      q = q.eq('language_code', languageCode);
    }

    final data = await q.order('created_at', ascending: false);

    return data.map<Book>((json) => Book.fromJson(json)).toList();
  }

  /// Vellum Exclusive olarak işaretlenen yayınlanmış kitaplar
  Future<List<Book>> getExclusiveBooks({int limit = 10}) async {
    final data = await _client
        .from('books')
        .select()
        .eq('status', 'published')
        .eq('is_exclusive', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return data.map<Book>((json) => Book.fromJson(json)).toList();
  }

  /// Bir kitabın Vellum Exclusive durumunu değiştir
  Future<void> setExclusive(String bookId, bool isExclusive) async {
    await _client
        .from('books')
        .update({'is_exclusive': isExclusive})
        .eq('id', bookId);
  }

  /// Tablodan sil (RLS izin veriyorsa).
  Future<void> deleteBook(String bookId) async {
    await _client.from('books').delete().eq('id', bookId);
  }

  /// Sunucudaki delete_book_cascade RPC ile kitabı ve ilişkili verileri siler.
  /// Sadece is_developer = true kullanıcılar başarılı olur; aksi halde exception.
  Future<void> deleteBookCascade(String bookId) async {
    await _client.rpc('delete_book_cascade', params: {'_book_id': bookId});
  }

  /// Kitap detayı açıldığında görüntülenme sayısını 1 artırır (RPC: increment_book_view)
  Future<void> incrementBookView(String bookId) async {
    await _client.rpc('increment_book_view', params: {'book_id': bookId});
  }
}

// ─── Providers ────────────────────────────────────

/// Book repository provider
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(ref.watch(supabaseClientProvider));
});

/// Yayınlanan kitaplar
final publishedBooksProvider = FutureProvider<List<Book>>((ref) async {
  return ref.read(bookRepositoryProvider).getPublishedBooks();
});

/// Vitrin / Editörün Seçimi: puana göre üst sıradaki kitaplar (hero alanı)
final featuredBooksProvider = FutureProvider<List<Book>>((ref) async {
  return ref.read(bookRepositoryProvider).getPublishedBooks(
    limit: 5,
    sortOrder: BookSortOrder.rating,
  );
});

/// Yazarın kendi kitapları
final myBooksProvider = FutureProvider<List<Book>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(bookRepositoryProvider).getMyBooks(profile.id);
});

/// Tek kitap detayı (family provider)
final bookDetailProvider =
    FutureProvider.family<Book?, String>((ref, bookId) async {
  return ref.read(bookRepositoryProvider).getBookById(bookId);
});

/// Bir yazarın yayınlanmış kitapları (family provider)
final authorBooksProvider =
    FutureProvider.family<List<Book>, String>((ref, authorId) async {
  return ref.read(bookRepositoryProvider).getPublishedBooksByAuthor(authorId);
});

/// Arama sorgusu state'i
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Filtre: sıralama ve kategori (ana sayfa)
final bookSortOrderProvider = StateProvider<BookSortOrder>((ref) => BookSortOrder.recent);
final bookCategoryFilterProvider = StateProvider<String?>((ref) => null);
final bookLanguageFilterProvider = StateProvider<String?>((ref) => null);

/// Arama sonuçları veya filtrelenmiş liste (arama boşsa filtre uygulanır)
final searchedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final sortOrder = ref.watch(bookSortOrderProvider);
  final category = ref.watch(bookCategoryFilterProvider);
  final languageCode = ref.watch(bookLanguageFilterProvider);

  if (query.trim().isNotEmpty) {
    return ref.read(bookRepositoryProvider).searchBooks(
          query.trim(),
          languageCode: languageCode,
        );
  }
  return ref.read(bookRepositoryProvider).getPublishedBooks(
        sortOrder: sortOrder,
        category: category,
        languageCode: languageCode,
      );
});

/// Vellum Exclusive rafı için kitaplar
final exclusiveBooksProvider = FutureProvider<List<Book>>((ref) async {
  return ref.read(bookRepositoryProvider).getExclusiveBooks(limit: 10);
});

/// Aranan yazarlar (global arama için)
final searchAuthorsProvider = FutureProvider<List<Profile>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  return ref.read(authRepositoryProvider).searchAuthors(query.trim());
});

/// Ana sayfada "Yeni Eklenenler" için son 5 kitap
final recentBooksProvider = FutureProvider<List<Book>>((ref) async {
  return ref.read(bookRepositoryProvider).getPublishedBooks(
    limit: 5,
    sortOrder: BookSortOrder.recent,
  );
});

/// "Tümünü Gör" sayfası: en fazla 25 kitap (son eklenenler)
final allBooksProvider = FutureProvider<List<Book>>((ref) async {
  return ref.read(bookRepositoryProvider).getPublishedBooks(
    limit: 25,
    sortOrder: BookSortOrder.recent,
  );
});
