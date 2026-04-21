import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

class ReviewReportRepository {
  ReviewReportRepository(this._client);
  final SupabaseClient _client;

  Future<void> createReport({
    required String reviewId,
    required String reporterUserId,
    required String reason,
  }) async {
    await _client.from('review_reports').insert({
      'review_id': reviewId,
      'reporter_user_id': reporterUserId,
      'reason': reason.trim().isEmpty ? 'inappropriate_content' : reason.trim(),
      'status': 'pending',
    });
  }
}

final reviewReportRepositoryProvider = Provider<ReviewReportRepository>((ref) {
  return ReviewReportRepository(ref.watch(supabaseClientProvider));
});
