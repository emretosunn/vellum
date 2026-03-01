import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../studio/data/chapter_repository.dart';
import 'book_repository.dart';
import 'read_books_repository.dart';
import '../domain/book.dart';

/// Yarıda bırakılan okuma: kitap ID + bölüm indeksi (cihazda saklanır).
class ReadingProgressEntry {
  const ReadingProgressEntry({
    required this.bookId,
    required this.chapterIndex,
    required this.updatedAt,
  });

  final String bookId;
  final int chapterIndex;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ReadingProgressEntry.fromJson(Map<String, dynamic> json) {
    return ReadingProgressEntry(
      bookId: json['bookId'] as String,
      chapterIndex: (json['chapterIndex'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

const _key = 'reading_progress';

/// Okuma ilerlemesini cihazda (SharedPreferences) saklar.
class ReadingProgressRepository {
  ReadingProgressRepository._();
  static final ReadingProgressRepository _instance = ReadingProgressRepository._();
  factory ReadingProgressRepository() => _instance;

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<ReadingProgressEntry>> _parseList() async {
    final prefs = await _p;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => ReadingProgressEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveList(List<ReadingProgressEntry> list) async {
    final prefs = await _p;
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Belirtilen kitap ve bölümü kaydeder (güncel tarihle).
  Future<void> saveProgress(String bookId, int chapterIndex) async {
    final now = DateTime.now();
    var list = await _parseList();
    list.removeWhere((e) => e.bookId == bookId);
    list.insert(0, ReadingProgressEntry(bookId: bookId, chapterIndex: chapterIndex, updatedAt: now));
    list = list.take(50).toList();
    await _saveList(list);
  }

  /// Bir kitabın kayıtlı bölüm indeksini döndürür (yoksa 0).
  Future<int> getChapterIndex(String bookId) async {
    final list = await _parseList();
    for (final e in list) {
      if (e.bookId == bookId) return e.chapterIndex;
    }
    return 0;
  }

  /// Devam edilebilecek kitapların (bookId, chapterIndex) çiftleri (en son okunana göre).
  Future<List<ReadingProgressEntry>> getContinueReadingEntries() async {
    return _parseList();
  }

  /// Kitabı listeden kaldır (bitirildiğinde "Devam Et"ten çıkar).
  Future<void> removeBook(String bookId) async {
    var list = await _parseList();
    list.removeWhere((e) => e.bookId == bookId);
    await _saveList(list);
  }
}

final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository();
});

/// Devam edilecek kitapların bookId + chapterIndex listesi (sıralı).
final continueReadingEntriesProvider = FutureProvider.autoDispose<List<ReadingProgressEntry>>((ref) {
  final repo = ref.watch(readingProgressRepositoryProvider);
  return repo.getContinueReadingEntries();
});

/// Devam edilecek kitaplar (Book + bölüm indeksi). Sadece yayında olan ve henüz bitirilmemiş kitaplar döner.
/// Son bölüme ulaşılmış kitaplar otomatik tamamlanır ve "Devam Et"ten kaldırılır.
final continueReadingBooksProvider = FutureProvider.autoDispose<List<({Book book, int chapterIndex})>>((ref) async {
  final entries = await ref.watch(continueReadingEntriesProvider.future);
  if (entries.isEmpty) return [];

  final bookIds = entries.map((e) => e.bookId).toSet().toList();
  final bookRepo = ref.read(bookRepositoryProvider);
  final chapterRepo = ref.read(chapterRepositoryProvider);
  final progressRepo = ref.read(readingProgressRepositoryProvider);

  final books = await bookRepo.getBooksByIds(bookIds);
  final byId = {for (final b in books) b.id: b};
  final chapterCounts = await chapterRepo.getChapterCountsByBookIds(bookIds);

  // Tamamlanmış kitapları filtrele (Supabase user_read_books)
  final authRepo = ref.read(authRepositoryProvider);
  final userId = authRepo.currentUser?.id;
  Set<String> completedIds = {};
  if (userId != null) {
    final readRepo = ref.read(readBooksRepositoryProvider);
    completedIds = (await readRepo.getCompletedBookIds(userId)).toSet();
  }

  // Son bölüme ulaşılmış ama "Bitir" tıklanmamış kitapları otomatik tamamla
  if (userId != null) {
    final readRepo = ref.read(readBooksRepositoryProvider);
    for (final e in entries) {
      if (completedIds.contains(e.bookId)) continue;
      final count = chapterCounts[e.bookId] ?? 0;
      if (count > 0 && e.chapterIndex >= count - 1) {
        await readRepo.markBookAsCompleted(userId: userId, bookId: e.bookId);
        await progressRepo.removeBook(e.bookId);
        completedIds.add(e.bookId);
        ref.invalidate(completedBooksProvider(userId));
        ref.invalidate(continueReadingEntriesProvider);
      }
    }
  }

  final result = <({Book book, int chapterIndex})>[];
  for (final e in entries) {
    if (completedIds.contains(e.bookId)) continue;
    final book = byId[e.bookId];
    if (book != null && book.status == BookStatus.published) {
      result.add((book: book, chapterIndex: e.chapterIndex));
    }
  }
  return result;
});
