import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'book_repository.dart';
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
}

final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>((ref) {
  return ReadingProgressRepository();
});

/// Devam edilecek kitapların bookId + chapterIndex listesi (sıralı).
final continueReadingEntriesProvider = FutureProvider.autoDispose<List<ReadingProgressEntry>>((ref) {
  final repo = ref.watch(readingProgressRepositoryProvider);
  return repo.getContinueReadingEntries();
});

/// Devam edilecek kitaplar (Book + bölüm indeksi). Sadece yayında olan kitaplar döner.
final continueReadingBooksProvider = FutureProvider.autoDispose<List<({Book book, int chapterIndex})>>((ref) async {
  final entries = await ref.watch(continueReadingEntriesProvider.future);
  if (entries.isEmpty) return [];
  final bookRepo = ref.read(bookRepositoryProvider);
  final books = await bookRepo.getBooksByIds(entries.map((e) => e.bookId).toList());
  final byId = {for (final b in books) b.id: b};
  final result = <({Book book, int chapterIndex})>[];
  for (final e in entries) {
    final book = byId[e.bookId];
    if (book != null && book.status == BookStatus.published) {
      result.add((book: book, chapterIndex: e.chapterIndex));
    }
  }
  return result;
});
