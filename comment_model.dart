class Comment {
  final String id;
  final String content;
  final String username;
  final String recipeId;
  final String userId;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.content,
    required this.username,
    required this.recipeId,
    required this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'username': username,
      'recipeId': recipeId,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      content: map['content'],
      username: map['username'],
      recipeId: map['recipeId'],
      userId: map['userId'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}