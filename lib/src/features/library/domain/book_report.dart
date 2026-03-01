/// Kitap şikayet kaydı (Supabase book_reports).
class BookReport {
  const BookReport({
    required this.id,
    required this.bookId,
    required this.reporterUserId,
    required this.message,
    required this.createdAt,
    this.status = ReportStatus.pending,
    this.readAt,
    this.readByUserId,
    this.bookTitle,
    this.reporterUsername,
    this.authorId,
  });

  final String id;
  final String bookId;
  final String reporterUserId;
  final String message;
  final DateTime createdAt;
  final ReportStatus status;
  final DateTime? readAt;
  final String? readByUserId;
  final String? bookTitle;
  final String? reporterUsername;
  /// Kitabın yazarı (books.author_id) — yazara uyarı göndermek için.
  final String? authorId;

  factory BookReport.fromJson(Map<String, dynamic> json) {
    return BookReport(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      reporterUserId: json['reporter_user_id'] as String,
      message: json['message'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      status: _parseStatus(json['status'] as String?),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      readByUserId: json['read_by_user_id'] as String?,
      bookTitle: json['book_title'] as String?,
      reporterUsername: json['reporter_username'] as String?,
    );
  }

  static ReportStatus _parseStatus(String? s) {
    switch (s) {
      case 'read':
        return ReportStatus.read;
      default:
        return ReportStatus.pending;
    }
  }

  bool get isRead => status == ReportStatus.read;
}

enum ReportStatus {
  pending,
  read,
}
