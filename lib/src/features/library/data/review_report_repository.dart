import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

class ReviewReportItem {
  const ReviewReportItem({
    required this.id,
    required this.reviewId,
    required this.reporterUserId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reviewId;
  final String reporterUserId;
  final String reason;
  final String status;
  final DateTime createdAt;

  factory ReviewReportItem.fromJson(Map<String, dynamic> json) {
    return ReviewReportItem(
      id: json['id'] as String,
      reviewId: json['review_id'] as String,
      reporterUserId: json['reporter_user_id'] as String,
      reason: (json['reason'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

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

  Future<List<ReviewReportItem>> getReports({int limit = 200}) async {
    final data = await _client
        .from('review_reports')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => ReviewReportItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> updateStatus({
    required String reportId,
    required String status,
  }) async {
    await _client
        .from('review_reports')
        .update({'status': status})
        .eq('id', reportId);
  }
}

final reviewReportRepositoryProvider = Provider<ReviewReportRepository>((ref) {
  return ReviewReportRepository(ref.watch(supabaseClientProvider));
});

final reviewReportsProvider =
    FutureProvider.autoDispose<List<ReviewReportItem>>((ref) async {
      return ref.read(reviewReportRepositoryProvider).getReports();
    });
