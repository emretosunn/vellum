import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../auth/data/auth_repository.dart';
import '../../subscription/services/subscription_service.dart';
import '../data/book_repository.dart';
import '../../studio/data/chapter_repository.dart';
import '../domain/chapter.dart';
import 'offline_book.dart';

/// Çevrimdışı kitap indirme ve okuma yöneticisi.
class OfflineDownloadManager {
  OfflineDownloadManager(this._ref);

  final Ref _ref;

  Future<Box<OfflineBook>> _openBox() async {
    if (!Hive.isAdapterRegistered(OfflineBookAdapter().typeId)) {
      Hive.registerAdapter(OfflineBookAdapter());
    }
    return Hive.openBox<OfflineBook>(offlineBooksBoxName);
  }

  /// Kitabı Supabase'den çekip Hive'a kaydeder.
  ///
  /// Bu metod çağrılmadan önce Pro kontrolü yapılmış olmalıdır, ancak
  /// ek güvenlik için burada da kontrol edilir.
  Future<void> downloadBook({required String bookId}) async {
    final subscriptionService = _ref.read(subscriptionServiceProvider);
    final isPro = await subscriptionService.isPro();
    if (!isPro) {
      throw Exception('Çevrimdışı indirme yalnızca Vellum Pro üyeleri içindir.');
    }

    final bookRepo = _ref.read(bookRepositoryProvider);
    final chapterRepo = _ref.read(chapterRepositoryProvider);
    final authRepo = _ref.read(authRepositoryProvider);

    final book = await bookRepo.getBookById(bookId);
    if (book == null) {
      throw Exception('Kitap bulunamadı.');
    }

    final author =
        await authRepo.getProfileById(book.authorId).catchError((_) => null);
    final chapters = await chapterRepo.getChaptersByBook(bookId);

    final texts = chapters
        .map((c) => _extractTextFromContent(c))
        .toList(growable: false);

    final offlineBook = OfflineBook(
      bookId: book.id,
      title: book.title,
      authorName: author?.username ?? 'Bilinmeyen Yazar',
      coverImage: book.coverImageUrl ?? '',
      chapters: texts,
    );

    final box = await _openBox();
    await box.put(book.id, offlineBook);
  }

  Future<OfflineBook?> getOfflineBook(String bookId) async {
    final box = await _openBox();
    return box.get(bookId);
  }

  /// Tüm indirilmiş kitapları döndürür (ana sayfa İndirilenler satırı için).
  Future<List<OfflineBook>> getAllOfflineBooks() async {
    final box = await _openBox();
    return box.values.toList();
  }

  Future<void> removeOfflineBook(String bookId) async {
    final box = await _openBox();
    await box.delete(bookId);
  }

  String _extractTextFromContent(Chapter chapter) {
    final raw = chapter.content['text'];
    if (raw is String) return raw;
    return '';
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

