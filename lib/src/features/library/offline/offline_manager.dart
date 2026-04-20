import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../auth/data/auth_repository.dart';
import '../../subscription/services/subscription_service.dart';
import '../../studio/data/chapter_repository.dart';
import '../data/book_repository.dart';
import '../domain/book.dart';
import '../domain/chapter.dart';
import 'local_database_service.dart';

/// SQLite tabanlı çevrimdışı indirme yöneticisi.
class OfflineManager {
  OfflineManager(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;

  /// Bir kitabı tüm bölümleri ile birlikte cihaza indirir.
  Future<void> downloadBook(Book book) async {
    final subscriptionService = _ref.read(subscriptionServiceProvider);
    final isPro = await subscriptionService.isPro();
    if (!isPro) {
      throw Exception('Çevrimdışı indirme yalnızca Vellum Pro üyeleri içindir.');
    }

    final chapterRepo = _ref.read(chapterRepositoryProvider);
    final authRepo = _ref.read(authRepositoryProvider);
    final dbService = _ref.read(localDatabaseServiceProvider);
    final db = await dbService.database;

    final author =
        await authRepo.getProfileById(book.authorId).catchError((_) => null);
    final chapters = await chapterRepo.getChaptersByBook(book.id);
    final localCoverPath = await _downloadCoverIfExists(book);

    await db.transaction((txn) async {
      await txn.insert(
        'offline_books',
        {
          'id': book.id,
          'title': book.title,
          'author_name': author?.username ?? 'Bilinmeyen Yazar',
          'local_cover_path': localCoverPath,
          'downloaded_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final chapter in chapters) {
        await txn.insert(
          'offline_chapters',
          {
            'id': chapter.id,
            'book_id': book.id,
            'title': chapter.title,
            'content': _extractChapterText(chapter),
            'order_index': chapter.order,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Book id ile indirme kolaylığı.
  Future<void> downloadBookById(String bookId) async {
    final bookRepo = _ref.read(bookRepositoryProvider);
    final book = await bookRepo.getBookById(bookId);
    if (book == null) {
      throw Exception('Kitap bulunamadı.');
    }
    await downloadBook(book);
  }

  Future<String?> _downloadCoverIfExists(Book book) async {
    final coverUrl = book.coverImageUrl;
    if (coverUrl == null || coverUrl.trim().isEmpty) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${docsDir.path}/offline_covers');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final ext = _fileExtensionFromUrl(coverUrl);
    final filePath = '${coversDir.path}/${book.id}.$ext';
    await _dio.download(coverUrl, filePath);
    return filePath;
  }

  String _fileExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final dot = last.lastIndexOf('.');
      if (dot > -1 && dot < last.length - 1) {
        return last.substring(dot + 1).toLowerCase();
      }
    } catch (_) {
      // ignore and fall through
    }
    return 'jpg';
  }

  /// Bölüm içeriğini düz metin olarak çıkarır.
  ///
  /// Öncelik:
  /// 1) content['text'] string ise doğrudan,
  /// 2) Quill delta ops dizisinden string insert'leri birleştir,
  /// 3) fallback olarak JSON string.
  String _extractChapterText(Chapter chapter) {
    final rawText = chapter.content['text'];
    if (rawText is String && rawText.trim().isNotEmpty) {
      return rawText;
    }

    final ops = chapter.content['ops'];
    if (ops is List) {
      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is Map) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return jsonEncode(chapter.content);
  }
}

final dioProvider = Provider<Dio>((ref) => Dio());

final offlineManagerProvider = Provider<OfflineManager>((ref) {
  return OfflineManager(ref, ref.watch(dioProvider));
});

