import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import 'book_repository.dart';
import '../domain/book.dart';

/// Kullanıcının bitirdiği kitapları Supabase'de saklar.
class ReadBooksRepository {
  ReadBooksRepository(this._client);
  final SupabaseClient _client;

  /// Kitabı tamamlandı olarak işaretle (son bölümde "Bitir" tıklandığında).
  Future<void> markBookAsCompleted({
    required String userId,
    required String bookId,
  }) async {
    await _client.from('user_read_books').upsert(
      {
        'user_id': userId,
        'book_id': bookId,
        'completed_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,book_id',
    );
  }

  /// Kullanıcının tamamladığı kitap ID'lerini getir (en son bitirilene göre).
  Future<List<String>> getCompletedBookIds(String userId) async {
    final data = await _client
        .from('user_read_books')
        .select('book_id')
        .eq('user_id', userId)
        .order('completed_at', ascending: false)
        .limit(50);

    if (data.isEmpty) return [];
    return data.map((e) => e['book_id'] as String).toList();
  }
}

final readBooksRepositoryProvider = Provider<ReadBooksRepository>((ref) {
  return ReadBooksRepository(ref.watch(supabaseClientProvider));
});

/// Kullanıcının tamamladığı kitaplar (sadece kendi profili için).
final completedBooksProvider =
    FutureProvider.autoDispose.family<List<Book>, String>((ref, userId) async {
  final readRepo = ref.watch(readBooksRepositoryProvider);
  final bookRepo = ref.watch(bookRepositoryProvider);

  final bookIds = await readRepo.getCompletedBookIds(userId);
  if (bookIds.isEmpty) return [];

  final books = await bookRepo.getBooksByIds(bookIds);
  final byId = {for (final b in books) b.id: b};
  return bookIds.map((id) => byId[id]).whereType<Book>().toList();
});
