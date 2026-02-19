class Review {
  final String id;
  final String bookId;
  final String userId;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? username;
  final String? avatarUrl;

  const Review({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.rating,
    this.comment = '',
    this.createdAt,
    this.updatedAt,
    this.username,
    this.avatarUrl,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return Review(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      userId: json['user_id'] as String,
      rating: json['rating'] as int,
      comment: (json['comment'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      username: profiles?['username'] as String?,
      avatarUrl: profiles?['avatar_url'] as String?,
    );
  }
}

class BookRatingStats {
  final double average;
  final int count;

  const BookRatingStats({this.average = 0.0, this.count = 0});
}
