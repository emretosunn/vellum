import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/book.dart';
import 'book_repository.dart';

/// Kitap beğeni: ekle/kaldır ve sayıları getir
class BookLikeRepository {
  BookLikeRepository(this._client);
  final SupabaseClient _client;

  static const _table = 'book_likes';

  /// Beğeniyi aç/kapat (varsa sil, yoksa ekle). Yeni durumu döner (true = beğenildi).
  Future<bool> toggleLike({required String bookId, required String userId}) async {
    final existing = await _client
        .from(_table)
        .select('id')
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client.from(_table).delete().eq('book_id', bookId).eq('user_id', userId);
      return false;
    } else {
      await _client.from(_table).insert({'book_id': bookId, 'user_id': userId});
      return true;
    }
  }

  /// Bir kitabın beğeni sayısı
  Future<int> getLikeCount(String bookId) async {
    final data = await _client.from(_table).select('id').eq('book_id', bookId);
    return data.length;
  }

  /// Giriş yapmış kullanıcı bu kitabı beğenmiş mi?
  Future<bool> isLikedByUser(String bookId, String userId) async {
    final row = await _client.from(_table).select('id').eq('book_id', bookId).eq('user_id', userId).maybeSingle();
    return row != null;
  }

  /// Bir yazarın tüm kitaplarına gelen toplam beğeni sayısı
  Future<int> getTotalLikesForAuthor(String authorId) async {
    final books = await _client.from('books').select('id').eq('author_id', authorId);
    if (books.isEmpty) return 0;
    final bookIds = books.map<String>((b) => b['id'] as String).toList();
    final data = await _client.from(_table).select('id').inFilter('book_id', bookIds);
    return data.length;
  }

  /// Giriş yapmış kullanıcının beğendiği kitap ID'leri (en son beğenilene göre)
  Future<List<String>> getLikedBookIds(String userId) async {
    final data = await _client
        .from(_table)
        .select('book_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map<String>((r) => r['book_id'] as String).toList();
  }
}

// ─── Providers ────────────────────────────────────

final bookLikeRepositoryProvider = Provider<BookLikeRepository>((ref) {
  return BookLikeRepository(ref.watch(supabaseClientProvider));
});

/// Kitap beğeni sayısı
final bookLikeCountProvider = FutureProvider.family<int, String>((ref, bookId) async {
  return ref.read(bookLikeRepositoryProvider).getLikeCount(bookId);
});

/// Mevcut kullanıcının bu kitabı beğenip beğenmediği
final isBookLikedByCurrentUserProvider = FutureProvider.family<bool, String>((ref, bookId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return false;
  return ref.read(bookLikeRepositoryProvider).isLikedByUser(bookId, profile.id);
});

/// Yazarın toplam beğeni sayısı (tüm kitaplarındaki beğeniler)
final authorTotalLikesProvider = FutureProvider.family<int, String>((ref, authorId) async {
  return ref.read(bookLikeRepositoryProvider).getTotalLikesForAuthor(authorId);
});

/// Giriş yapmış kullanıcının beğendiği kitaplar (liste, en son beğenilen önce).
final likedBooksProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  final ids = await ref.read(bookLikeRepositoryProvider).getLikedBookIds(profile.id);
  if (ids.isEmpty) return [];
  return ref.read(bookRepositoryProvider).getBooksByIds(ids);
});
