import 'package:flutter/material.dart';
import 'user_model.dart';
import 'database_helper.dart'; // Assurez-vous d'avoir cette importation

class UserProvider with ChangeNotifier {
  User? _user;
  List<User> _allUsers = [];
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  List<User> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> login(User user) async {
    _user = user;
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  Future<List<User>> getAllUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> maps = await db.query('users');

      _allUsers = maps.map((map) => User.fromMap(map)).toList();
      return _allUsers; // Ajoutez cette ligne

    } catch (e) {
      _error = 'Erreur de chargement';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> deleteUser(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;
      await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      _allUsers.removeWhere((user) => user.id == userId);
    } catch (e) {
      _error = 'Échec de la suppression de l\'utilisateur';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}