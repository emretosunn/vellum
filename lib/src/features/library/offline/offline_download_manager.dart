import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_book.dart';
import 'local_database_service.dart';
import 'offline_manager.dart';

/// Çevrimdışı kitap indirme ve okuma yöneticisi.
class OfflineDownloadManager {
  OfflineDownloadManager(this._ref);

  final Ref _ref;

  /// Kitabı Supabase'den çekip Hive'a kaydeder.
  ///
  /// Bu metod çağrılmadan önce Pro kontrolü yapılmış olmalıdır, ancak
  /// ek güvenlik için burada da kontrol edilir.
  Future<void> downloadBook({required String bookId}) async {
    await _ref.read(offlineManagerProvider).downloadBookById(bookId);
  }

  Future<OfflineBook?> getOfflineBook(String bookId) async {
    final db = await _ref.read(localDatabaseServiceProvider).database;
    final bookRow = await db.query(
      'offline_books',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (bookRow.isEmpty) return null;

    final chapterRows = await db.query(
      'offline_chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'order_index ASC',
    );

    final row = bookRow.first;
    return OfflineBook(
      bookId: row['id'] as String,
      title: row['title'] as String,
      authorName: row['author_name'] as String? ?? 'Bilinmeyen Yazar',
      coverImage: row['local_cover_path'] as String? ?? '',
      chapters: chapterRows
          .map((e) => (e['content'] as String?) ?? '')
          .toList(growable: false),
    );
  }

  /// Tüm indirilmiş kitapları döndürür (ana sayfa İndirilenler satırı için).
  Future<List<OfflineBook>> getAllOfflineBooks() async {
    final db = await _ref.read(localDatabaseServiceProvider).database;
    final rows = await db.query(
      'offline_books',
      orderBy: 'downloaded_at DESC',
    );

    return rows
        .map(
          (row) => OfflineBook(
            bookId: row['id'] as String,
            title: row['title'] as String,
            authorName: row['author_name'] as String? ?? 'Bilinmeyen Yazar',
            coverImage: row['local_cover_path'] as String? ?? '',
            // Liste satırında chapter'lara ihtiyaç yok; detayda ayrıca çekiliyor.
            chapters: const [],
          ),
        )
        .toList(growable: false);
  }

  Future<void> removeOfflineBook(String bookId) async {
    final db = await _ref.read(localDatabaseServiceProvider).database;
    final rows = await db.query(
      'offline_books',
      columns: ['local_cover_path'],
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final localCoverPath = rows.first['local_cover_path'] as String?;
      if (localCoverPath != null && localCoverPath.isNotEmpty) {
        final file = File(localCoverPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    // offline_chapters, FK ON DELETE CASCADE ile otomatik temizlenir.
    await db.delete('offline_books', where: 'id = ?', whereArgs: [bookId]);
  }
}

final offlineDownloadManagerProvider =
    Provider<OfflineDownloadManager>((ref) => OfflineDownloadManager(ref));

/// Ana sayfada "İndirilenler" satırı için tüm çevrimdışı kitaplar.
final offlineBooksListProvider =
    FutureProvider.autoDispose<List<OfflineBook>>((ref) async {
  final manager = ref.read(offlineDownloadManagerProvider);
  return manager.getAllOfflineBooks();
});

