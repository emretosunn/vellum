import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../../library/domain/chapter.dart';

/// Bölüm CRUD repository
class ChapterRepository {
  ChapterRepository(this._client);
  final SupabaseClient _client;

  /// Birden fazla kitabın bölüm sayılarını tek sorguda getir (bookId -> count).
  Future<Map<String, int>> getChapterCountsByBookIds(List<String> bookIds) async {
    if (bookIds.isEmpty) return {};
    final data = await _client
        .from('chapters')
        .select('book_id')
        .inFilter('book_id', bookIds);
    final counts = <String, int>{};
    for (final id in bookIds) counts[id] = 0;
    for (final row in data) {
      final bid = row['book_id'] as String?;
      if (bid != null) counts[bid] = (counts[bid] ?? 0) + 1;
    }
    return counts;
  }

  /// Kitabın bölümlerini listele
  Future<List<Chapter>> getChaptersByBook(String bookId) async {
    final data = await _client
        .from('chapters')
        .select()
        .eq('book_id', bookId)
        .order('order', ascending: true);

    return data.map((json) => Chapter.fromJson(json)).toList();
  }

  /// Tek bölüm (içerik dahil)
  Future<Chapter?> getChapterById(String chapterId) async {
    final data = await _client
        .from('chapters')
        .select()
        .eq('id', chapterId)
        .maybeSingle();

    if (data == null) return null;
    return Chapter.fromJson(data);
  }

  /// Yeni bölüm oluştur
  Future<Chapter> createChapter({
    required String bookId,
    required String title,
    int order = 0,
  }) async {
    final data = await _client
        .from('chapters')
        .insert({
          'book_id': bookId,
          'title': title,
          'order': order,
          'content': <String, dynamic>{},
        })
        .select()
        .single();

    return Chapter.fromJson(data);
  }

  /// Bölüm içeriğini güncelle (flutter_quill Delta JSON)
  Future<Chapter> updateChapter({
    required String chapterId,
    String? title,
    Map<String, dynamic>? content,
    int? order,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (order != null) updates['order'] = order;

    final data = await _client
        .from('chapters')
        .update(updates)
        .eq('id', chapterId)
        .select()
        .single();

    return Chapter.fromJson(data);
  }

  /// Bölüm sil
  Future<void> deleteChapter(String chapterId) async {
    await _client.from('chapters').delete().eq('id', chapterId);
  }
}

// ─── Providers ────────────────────────────────────

/// Chapter repository provider
final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  return ChapterRepository(ref.watch(supabaseClientProvider));
});

/// Kitabın bölümleri (family provider)
final chaptersByBookProvider =
    FutureProvider.family<List<Chapter>, String>((ref, bookId) async {
  return ref.read(chapterRepositoryProvider).getChaptersByBook(bookId);
});

/// Tek bölüm detayı (family provider)
final chapterDetailProvider =
    FutureProvider.family<Chapter?, String>((ref, chapterId) async {
  return ref.read(chapterRepositoryProvider).getChapterById(chapterId);
});
