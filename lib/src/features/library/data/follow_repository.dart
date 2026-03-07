import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Yazar takip (follow) CRUD.
class FollowRepository {
  FollowRepository(this._client);
  final SupabaseClient _client;

  /// [followerId] kullanıcısının takip ettiği yazar id'leri.
  Future<List<String>> getFollowingIds(String followerId) async {
    final data = await _client
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', followerId);
    return (data as List).map((e) => e['following_id'] as String).toList();
  }

  /// Takip ediyor mu?
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) return false;
    final data = await _client
        .from('user_follows')
        .select('follower_id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return data != null;
  }

  /// Takip et.
  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) return;
    await _client.from('user_follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  /// Takipten çık.
  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    await _client
        .from('user_follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
  }

  /// Bir kullanıcının (yazarın) takipçi sayısı.
  Future<int> getFollowerCount(String followingId) async {
    final data = await _client
        .from('user_follows')
        .select('follower_id')
        .eq('following_id', followingId);
    return (data as List).length;
  }
}

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref.watch(supabaseClientProvider));
});

/// Mevcut kullanıcının takip ettiği yazar id listesi.
final followingIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final auth = ref.watch(authRepositoryProvider);
  final userId = auth.currentUser?.id;
  if (userId == null) return [];
  return ref.read(followRepositoryProvider).getFollowingIds(userId);
});

/// Belirli bir yazarı takip ediyor mu?
final isFollowingProvider =
    FutureProvider.autoDispose.family<bool, ({String followerId, String followingId})>((ref, params) async {
  return ref.read(followRepositoryProvider).isFollowing(
        followerId: params.followerId,
        followingId: params.followingId,
      );
});

/// Bir kullanıcının takipçi sayısı (profil istatistikleri için).
final followerCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, followingId) async {
  return ref.read(followRepositoryProvider).getFollowerCount(followingId);
});
