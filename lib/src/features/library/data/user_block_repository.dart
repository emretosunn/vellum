import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Kullanıcının engellediği kullanıcılar.
class UserBlockRepository {
  UserBlockRepository(this._client);
  final SupabaseClient _client;

  Future<List<String>> getBlockedUserIds(String userId) async {
    final data = await _client
        .from('user_blocks')
        .select('blocked_user_id')
        .eq('user_id', userId);
    return (data as List)
        .map((e) => e['blocked_user_id'] as String)
        .toList();
  }

  Future<bool> isBlocked({
    required String userId,
    required String blockedUserId,
  }) async {
    final row = await _client
        .from('user_blocks')
        .select('id')
        .eq('user_id', userId)
        .eq('blocked_user_id', blockedUserId)
        .maybeSingle();
    return row != null;
  }

  Future<void> blockUser({
    required String userId,
    required String blockedUserId,
  }) async {
    if (userId == blockedUserId) return;
    await _client.from('user_blocks').upsert(
      {
        'user_id': userId,
        'blocked_user_id': blockedUserId,
      },
      onConflict: 'user_id,blocked_user_id',
    );
  }

  Future<void> unblockUser({
    required String userId,
    required String blockedUserId,
  }) async {
    await _client
        .from('user_blocks')
        .delete()
        .eq('user_id', userId)
        .eq('blocked_user_id', blockedUserId);
  }
}

final userBlockRepositoryProvider = Provider<UserBlockRepository>((ref) {
  return UserBlockRepository(ref.watch(supabaseClientProvider));
});

final blockedUserIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return [];
  return ref.read(userBlockRepositoryProvider).getBlockedUserIds(uid);
});

final isBlockedUserProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, blockedUserId) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return false;
  return ref.read(userBlockRepositoryProvider).isBlocked(
        userId: uid,
        blockedUserId: blockedUserId,
      );
});
