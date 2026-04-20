import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../offline/local_database_service.dart';
import 'book_repository.dart';
import '../domain/book.dart';

/// Kullanıcının bitirdiği kitapları Supabase'de saklar.
class ReadBooksRepository {
  ReadBooksRepository(this._client, this._dbService);
  final SupabaseClient _client;
  final LocalDatabaseService _dbService;

  /// Kitabı tamamlandı olarak işaretle (son bölümde "Bitir" tıklandığında).
  Future<void> markBookAsCompleted({
    required String userId,
    required String bookId,
  }) async {
    final completedAt = DateTime.now().toIso8601String();
    try {
      await _upsertRemote(
        userId: userId,
        bookId: bookId,
        completedAt: completedAt,
      );
      await _removeLocalQueued(userId: userId, bookId: bookId);
    } catch (_) {
      await _upsertLocalQueued(
        userId: userId,
        bookId: bookId,
        completedAt: completedAt,
      );
    }
  }

  /// Kullanıcının tamamladığı kitap ID'lerini getir (en son bitirilene göre).
  Future<List<String>> getCompletedBookIds(String userId) async {
    // Uygun durumda bekleyen local kayıtları önce remote'a basmayı dene.
    await syncPendingCompletions(userId);

    final localPendingIds = await _getLocalQueuedBookIds(userId);
    try {
      final data = await _client
          .from('user_read_books')
          .select('book_id')
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(50);

      final remoteIds = data.map((e) => e['book_id'] as String).toList();
      if (localPendingIds.isEmpty) return remoteIds;

      final merged = <String>[];
      final seen = <String>{};
      for (final id in [...localPendingIds, ...remoteIds]) {
        if (seen.add(id)) merged.add(id);
      }
      return merged;
    } catch (_) {
      // Tam offline senaryoda en azından local kuyruk profilde "okundu" mantığına
      // temel veri sağlayabilsin.
      return localPendingIds;
    }
  }

  Future<void> syncPendingCompletions(String userId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'offline_read_events',
      where: 'user_id = ? AND synced = 0',
      whereArgs: [userId],
      orderBy: 'completed_at DESC',
      limit: 100,
    );
    if (rows.isEmpty) return;

    for (final row in rows) {
      final bookId = row['book_id'] as String;
      final completedAt = row['completed_at'] as String;
      try {
        await _upsertRemote(
          userId: userId,
          bookId: bookId,
          completedAt: completedAt,
        );
        await db.update(
          'offline_read_events',
          {'synced': 1},
          where: 'user_id = ? AND book_id = ?',
          whereArgs: [userId, bookId],
        );
      } catch (_) {
        // Ağ tekrar gittiyse kalan kayıtları bir sonraki turda deneriz.
      }
    }
  }

  Future<void> _upsertRemote({
    required String userId,
    required String bookId,
    required String completedAt,
  }) async {
    await _client.from('user_read_books').upsert(
      {
        'user_id': userId,
        'book_id': bookId,
        'completed_at': completedAt,
      },
      onConflict: 'user_id,book_id',
    );
  }

  Future<void> _upsertLocalQueued({
    required String userId,
    required String bookId,
    required String completedAt,
  }) async {
    final db = await _dbService.database;
    await db.insert(
      'offline_read_events',
      {
        'user_id': userId,
        'book_id': bookId,
        'completed_at': completedAt,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _removeLocalQueued({
    required String userId,
    required String bookId,
  }) async {
    final db = await _dbService.database;
    await db.delete(
      'offline_read_events',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );
  }

  Future<List<String>> _getLocalQueuedBookIds(String userId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'offline_read_events',
      columns: ['book_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'completed_at DESC',
      limit: 50,
    );
    return rows.map((e) => e['book_id'] as String).toList();
  }
}

final readBooksRepositoryProvider = Provider<ReadBooksRepository>((ref) {
  return ReadBooksRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localDatabaseServiceProvider),
  );
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
