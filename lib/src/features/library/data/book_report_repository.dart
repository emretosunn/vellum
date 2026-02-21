import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/book_report.dart';

/// Kitap şikayetleri repository (book_reports tablosu).
class BookReportRepository {
  BookReportRepository(this._client);
  final SupabaseClient _client;

  /// Kullanıcı kitap şikayeti gönderir.
  Future<void> createReport({
    required String bookId,
    required String reporterUserId,
    required String message,
  }) async {
    await _client.from('book_reports').insert({
      'book_id': bookId,
      'reporter_user_id': reporterUserId,
      'message': message,
      'status': 'pending',
    });
  }

  /// Geliştirici: tüm şikayetleri listeler.
  Future<List<BookReport>> getReports() async {
    final data = await _client
        .from('book_reports')
        .select()
        .order('created_at', ascending: false);

    return (data as List)
        .map((json) => BookReport.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Şikayeti okundu işaretle ve şikayetçiye bildirim gönder.
  Future<void> markAsRead({
    required String reportId,
    required String readByUserId,
    required String reporterUserId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('book_reports').update({
      'status': 'read',
      'read_at': now,
      'read_by_user_id': readByUserId,
    }).eq('id', reportId);

    await _client.from('notifications').insert({
      'user_id': reporterUserId,
      'title': 'Şikayet talebiniz',
      'body': 'Talebiniz değerlendirmeye alındı. İnceleme sonucu hakkında bilgi verilecektir.',
      'type': 'system',
      'is_read': false,
    });
  }
}

final bookReportRepositoryProvider = Provider<BookReportRepository>((ref) {
  return BookReportRepository(ref.watch(supabaseClientProvider));
});

/// Geliştirici şikayet listesi (sadece developer görür).
final bookReportsListProvider =
    FutureProvider.autoDispose<List<BookReport>>((ref) async {
  return ref.read(bookReportRepositoryProvider).getReports();
});
