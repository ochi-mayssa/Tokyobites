import 'dart:convert';

class Recipe {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> steps;
  final Map<String, double> userRatings;
  final String? videoUrl;
  final String userId;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.userRatings,
    this.videoUrl,
    required this.userId,
    required this.createdAt,
  });

  double get rating {
    // This will now use the averageRating from the query
    return userRatings.isNotEmpty
        ? userRatings.values.reduce((a, b) => a + b) / userRatings.length
        : 0.0;
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    // Handle potential null values and type conversions
    return Recipe(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      ingredients: (map['ingredients']?.toString() ?? '').split('||'),
      steps: (map['steps']?.toString() ?? '').split('||'),
      userRatings: {}, // Initialize empty, will be populated separately
      videoUrl: map['videoUrl']?.toString(),
      userId: map['userId']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'ingredients': ingredients.join('||'),
      'steps': steps.join('||'),
      'userRatings': jsonEncode(userRatings),
      'videoUrl': videoUrl,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    List<String>? ingredients,
    List<String>? steps,
    Map<String, double>? userRatings,
    String? videoUrl,
    String? userId,
    DateTime? createdAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      userRatings: userRatings ?? this.userRatings,
      videoUrl: videoUrl ?? this.videoUrl,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}