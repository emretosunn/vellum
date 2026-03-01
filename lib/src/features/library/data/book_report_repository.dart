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

  /// Geliştirici: tüm şikayetleri listeler (kitap bilgisiyle).
  Future<List<BookReport>> getReports() async {
    final data = await _client
        .from('book_reports')
        .select()
        .order('created_at', ascending: false);

    final reports =
        (data as List)
            .map((json) => BookReport.fromJson(json as Map<String, dynamic>))
            .toList();

    if (reports.isEmpty) return reports;

    final bookIds = reports.map((r) => r.bookId).toSet().toList();
    final booksData = await _client
        .from('books')
        .select('id, title, author_id')
        .inFilter('id', bookIds);

    final bookMap = {
      for (final b in booksData) b['id'] as String: b,
    };

    return reports.map((r) {
      final book = bookMap[r.bookId];
      return BookReport(
        id: r.id,
        bookId: r.bookId,
        reporterUserId: r.reporterUserId,
        message: r.message,
        createdAt: r.createdAt,
        status: r.status,
        readAt: r.readAt,
        readByUserId: r.readByUserId,
        bookTitle: book?['title'] as String? ?? r.bookTitle,
        reporterUsername: r.reporterUsername,
        authorId: book?['author_id'] as String?,
      );
    }).toList();
  }

  /// Yazara uyarı bildirimi gönder (şikayet edilen kitabın yazarına).
  /// Kitap yayındaysa otomatik taslağa alınır; yazar düzelttikten sonra tekrar yayınlayabilir.
  Future<void> warnAuthor({
    required String bookId,
    String? customMessage,
  }) async {
    final bookData = await _client
        .from('books')
        .select('author_id, title, status')
        .eq('id', bookId)
        .maybeSingle();

    if (bookData == null) return;

    final authorId = bookData['author_id'] as String?;
    final title = bookData['title'] as String? ?? 'Kitabınız';
    final status = bookData['status'] as String?;

    if (authorId == null || authorId.isEmpty) return;

    // Yayındaysa otomatik taslağa al
    bool movedToDraft = false;
    if (status == 'published') {
      await _client.from('books').update({
        'status': 'draft',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookId);
      movedToDraft = true;
    }

    final baseMessage = customMessage ??
        '"$title" hakkında alınan şikayetler nedeniyle size uyarı gönderiliyor. Lütfen içeriğinizi gözden geçirin.';
    final body = movedToDraft
        ? '$baseMessage Kitabınız taslağa alındı. Sorunu düzelttikten sonra tekrar yayınlayabilirsiniz.'
        : baseMessage;

    await _client.from('notifications').insert({
      'user_id': authorId,
      'title': 'Yönetici Uyarısı',
      'body': body,
      'type': 'admin_warning',
      'is_read': false,
    });
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
