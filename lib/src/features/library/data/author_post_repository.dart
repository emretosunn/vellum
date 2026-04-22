import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/author_post.dart';
import 'user_block_repository.dart';

/// Yazar paylaşımları (sadece metin).
class AuthorPostRepository {
  AuthorPostRepository(this._client);
  final SupabaseClient _client;

  /// Bir yazarın postlarını getir (en yeni önce).
  Future<List<AuthorPost>> getPostsByAuthor(
    String authorId, {
    int limit = 50,
  }) async {
    final data = await _client
        .from('author_posts')
        .select()
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List<dynamic>)
        .map((e) => AuthorPost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Takip edilen yazarların postlarını getir (feed, en yeni önce).
  Future<List<AuthorPost>> getFeedForFollower(
    String followerId, {
    int limit = 100,
  }) async {
    if (followerId.isEmpty) return [];
    final followings = await _client
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', followerId);
    final ids = (followings as List)
        .map((e) => e['following_id'] as String)
        .toSet()
        .toList();
    if (ids.isEmpty) return [];
    final data = await _client
        .from('author_posts')
        .select()
        .inFilter('author_id', ids)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List<dynamic>)
        .map((e) => AuthorPost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Post oluştur (sadece metin).
  Future<AuthorPost> createPost({
    required String authorId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) throw Exception('İçerik boş olamaz.');
    final data = await _client
        .from('author_posts')
        .insert({'author_id': authorId, 'content': trimmed})
        .select()
        .single();
    return AuthorPost.fromJson(Map<String, dynamic>.from(data));
  }

  /// Post sil (sadece kendi postu).
  Future<void> deletePost(String postId, String authorId) async {
    await _client
        .from('author_posts')
        .delete()
        .eq('id', postId)
        .eq('author_id', authorId);
  }
}

final authorPostRepositoryProvider = Provider<AuthorPostRepository>((ref) {
  return AuthorPostRepository(ref.watch(supabaseClientProvider));
});

/// Bir yazarın post listesi.
final authorPostsProvider = FutureProvider.autoDispose
    .family<List<AuthorPost>, String>((ref, authorId) async {
      final blockedIds = await ref.watch(blockedUserIdsProvider.future);
      if (blockedIds.contains(authorId)) return [];
      return ref.read(authorPostRepositoryProvider).getPostsByAuthor(authorId);
    });

/// Takip Edilenler feed: takip ettiğim yazarların postları.
final followingFeedProvider = FutureProvider.autoDispose<List<AuthorPost>>((
  ref,
) async {
  final userId = ref.watch(authRepositoryProvider).currentUser?.id;
  if (userId == null) return [];
  final posts = await ref
      .read(authorPostRepositoryProvider)
      .getFeedForFollower(userId);
  final blockedIds = await ref.watch(blockedUserIdsProvider.future);
  if (blockedIds.isEmpty) return posts;
  return posts.where((p) => !blockedIds.contains(p.authorId)).toList();
});
