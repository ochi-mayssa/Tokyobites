import 'package:flutter/material.dart';
import 'recipe_model.dart';
import 'database_helper.dart';

class RecipeProvider with ChangeNotifier {
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;

  Future<List<Recipe>> getAllRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> maps = await db.query('recipes');

      _recipes = maps.map((map) => Recipe.fromMap(map)).toList();
      return _recipes;

    } catch (e) {
      _error = 'Error loading recipes';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteRecipe(String recipeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper().database;
      await db.delete(
        'recipes',
        where: 'id = ?',
        whereArgs: [recipeId],
      );

      _recipes.removeWhere((recipe) => recipe.id == recipeId);
    } catch (e) {
      _error = 'Échec de la suppression de la recette';
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