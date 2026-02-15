import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../../library/domain/chapter.dart';

/// Bölüm CRUD repository
class ChapterRepository {
  ChapterRepository(this._client);
  final SupabaseClient _client;

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
    bool isFree = false,
    int price = 10,
  }) async {
    final data = await _client
        .from('chapters')
        .insert({
          'book_id': bookId,
          'title': title,
          'order': order,
          'is_free': isFree,
          'price': price,
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
    bool? isFree,
    int? price,
    int? order,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (isFree != null) updates['is_free'] = isFree;
    if (price != null) updates['price'] = price;
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
