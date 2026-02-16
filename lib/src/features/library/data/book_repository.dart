import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/book.dart';

/// Kitap CRUD repository
class BookRepository {
  BookRepository(this._client);
  final SupabaseClient _client;

  /// Yayınlanan kitapları listele (vitrin)
  Future<List<Book>> getPublishedBooks({int limit = 20, int offset = 0}) async {
    final data = await _client
        .from('books')
        .select()
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return data.map((json) => Book.fromJson(json)).toList();
  }

  /// Tek kitap detayı
  Future<Book?> getBookById(String bookId) async {
    final data =
        await _client.from('books').select().eq('id', bookId).maybeSingle();

    if (data == null) return null;
    return Book.fromJson(data);
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
  }) async {
    final data = await _client
        .from('books')
        .insert({
          'author_id': authorId,
          'title': title,
          'summary': summary,
          'cover_image_url': coverImageUrl,
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
  }) async {
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (title != null) updates['title'] = title;
    if (summary != null) updates['summary'] = summary;
    if (coverImageUrl != null) updates['cover_image_url'] = coverImageUrl;
    if (status != null) updates['status'] = status;

    final data = await _client
        .from('books')
        .update(updates)
        .eq('id', bookId)
        .select()
        .single();

    return Book.fromJson(data);
  }

  /// Kitap sil
  /// Kitap arama (başlık veya özet üzerinden)
  Future<List<Book>> searchBooks(String query) async {
    final data = await _client
        .from('books')
        .select()
        .eq('status', 'published')
        .or('title.ilike.%$query%,summary.ilike.%$query%')
        .order('created_at', ascending: false);

    return data.map<Book>((json) => Book.fromJson(json)).toList();
  }

  Future<void> deleteBook(String bookId) async {
    await _client.from('books').delete().eq('id', bookId);
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

/// Arama sorgusu state'i
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Arama sonuçları
final searchedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return ref.read(bookRepositoryProvider).getPublishedBooks();
  }
  return ref.read(bookRepositoryProvider).searchBooks(query.trim());
});
