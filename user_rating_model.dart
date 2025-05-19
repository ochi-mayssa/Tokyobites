class UserRating {
  final String userId;
  final String recipeId;
  final double rating;

  UserRating({
    required this.userId,
    required this.recipeId,
    required this.rating,
  });

  factory UserRating.fromMap(Map<String, dynamic> map) {
    return UserRating(
      userId: map['userId'],
      recipeId: map['recipeId'],
      rating: map['rating'].toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'recipeId': recipeId,
      'rating': rating,
    };
  }
}