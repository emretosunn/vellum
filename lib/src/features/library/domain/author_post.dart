/// Yazar paylaşımı (sadece metin, Twitter benzeri).
class AuthorPost {
  AuthorPost({
    required this.id,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String content;
  final DateTime createdAt;

  factory AuthorPost.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'];
    return AuthorPost(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: createdAt is DateTime
          ? createdAt
          : DateTime.parse(createdAt as String),
    );
  }
}
