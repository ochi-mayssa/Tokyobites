import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'user_model.dart';

class AuthService {
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User?> login(String email, String password) async {
    try {
      await Future.delayed(Duration(seconds: 1));
      final hashedPassword = _hashPassword(password);
      if (email == "test@example.com" && hashedPassword == _hashPassword("password")) {
        return User(
            id: "1",
            username: "Test User",
            email: email,
            password: hashedPassword,
            createdAt: DateTime.now(),
            isAdmin: true
        );
      }
      return null;
    } catch (e) {
      print('Error during login: $e');
      rethrow;
    }
  }

  Future<User?> register(String username, String email, String password) async {
    try {
      await Future.delayed(Duration(seconds: 1));
      final hashedPassword = _hashPassword(password);
      return User(
          id: "2",
          username: username,
          email: email,
          password: hashedPassword,
          createdAt: DateTime.now(),
          isAdmin: false
      );
    } catch (e) {
      print('Error during registration: $e');
      rethrow;
    }
  }
}