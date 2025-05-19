class User {
  final String id;
  final String username;
  final String email;
  final String password; // À hasher en production
  final String? profileImage;
  final bool isAdmin;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.profileImage,
    this.isAdmin = false,
    required this.createdAt,
  });


  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'],
      profileImage: map['profileImage'],
      isAdmin: map['isAdmin'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'profileImage': profileImage,
      'isAdmin': isAdmin ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? username,
    String? email,
    String? password,
    String? profileImage,
    bool? isAdmin,
  }) {
    return User(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      profileImage: profileImage ?? this.profileImage,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt,
    );
  }
}