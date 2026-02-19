import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/review.dart';

class ReviewRepository {
  ReviewRepository(this._client);
  final SupabaseClient _client;

  Future<List<Review>> getBookReviews(String bookId) async {
    final data = await _client
        .from('reviews')
        .select('*, profiles!reviews_user_id_profiles_fkey(username, avatar_url)')
        .eq('book_id', bookId)
        .order('created_at', ascending: false);

    return data.map((json) => Review.fromJson(json)).toList();
  }

  Future<BookRatingStats> getBookRatingStats(String bookId) async {
    final data = await _client
        .from('reviews')
        .select('rating')
        .eq('book_id', bookId);

    if (data.isEmpty) return const BookRatingStats();

    final ratings = data.map((r) => r['rating'] as int).toList();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;
    return BookRatingStats(average: avg, count: ratings.length);
  }

  Future<Review?> getUserReview(String bookId, String userId) async {
    final data = await _client
        .from('reviews')
        .select('*, profiles!reviews_user_id_profiles_fkey(username, avatar_url)')
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Review.fromJson(data);
  }

  Future<Review> addOrUpdateReview({
    required String bookId,
    required String userId,
    required int rating,
    required String comment,
  }) async {
    final data = await _client
        .from('reviews')
        .upsert(
          {
            'book_id': bookId,
            'user_id': userId,
            'rating': rating,
            'comment': comment,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'book_id,user_id',
        )
        .select('*, profiles!reviews_user_id_profiles_fkey(username, avatar_url)')
        .single();

    return Review.fromJson(data);
  }

  Future<void> deleteReview(String reviewId) async {
    await _client.from('reviews').delete().eq('id', reviewId);
  }
}

// ─── Providers ────────────────────────────────────

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(supabaseClientProvider));
});

final bookReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, bookId) async {
  return ref.read(reviewRepositoryProvider).getBookReviews(bookId);
});

final bookRatingStatsProvider =
    FutureProvider.family<BookRatingStats, String>((ref, bookId) async {
  return ref.read(reviewRepositoryProvider).getBookRatingStats(bookId);
});

final userReviewProvider =
    FutureProvider.family<Review?, String>((ref, bookId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  return ref
      .read(reviewRepositoryProvider)
      .getUserReview(bookId, profile.id);
});
