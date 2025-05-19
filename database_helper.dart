import 'package:newapp/user_rating_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'user_model.dart';
import 'recipe_model.dart';
import 'comment_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'app_database.db');

      return await openDatabase(
        path,
        version: 5, // Update to latest version
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    } catch (e) {
      print('Database initialization error: $e');
      rethrow;
    }
  }


  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL,
        profileImage TEXT,
        isAdmin INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
    CREATE TABLE recipes (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL,
      imageUrl TEXT NOT NULL,
      ingredients TEXT NOT NULL,
      steps TEXT NOT NULL,
      videoUrl TEXT,
      userId TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');

    await db.execute('''
      CREATE TABLE user_ratings (
      userId TEXT NOT NULL,
      recipeId TEXT NOT NULL,
      rating REAL NOT NULL,
      PRIMARY KEY (userId, recipeId),
      FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (recipeId) REFERENCES recipes(id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
      CREATE INDEX idx_recipes_category 
      ON recipes (category)
    ''');

    await db.execute('''
      CREATE TABLE comments (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        username TEXT NOT NULL,
        recipeId TEXT NOT NULL,
        userId TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        userId TEXT NOT NULL,
        recipeId TEXT NOT NULL,
        PRIMARY KEY (userId, recipeId)
      )
    ''');
  }
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE favorites (
          userId TEXT NOT NULL,
          recipeId TEXT NOT NULL,
          PRIMARY KEY (userId, recipeId)
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE INDEX idx_recipes_category 
        ON recipes (category)
      ''');
    }
    if (oldVersion < 4) {
      // Create user_ratings table
      await db.execute('''
        CREATE TABLE user_ratings (
        userId TEXT NOT NULL,
        recipeId TEXT NOT NULL,
        rating REAL NOT NULL,
        PRIMARY KEY (userId, recipeId)
      )
    ''');

      // Migrate recipes table (remove rating column)
      await db.execute('ALTER TABLE recipes RENAME TO old_recipes');
      await db.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        steps TEXT NOT NULL,
        videoUrl TEXT,
        userId TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
      await db.execute('''
      INSERT INTO recipes (id, title, description, category, imageUrl, 
        ingredients, steps, videoUrl, userId, createdAt)
      SELECT id, title, description, category, imageUrl, 
        ingredients, steps, videoUrl, userId, createdAt
      FROM old_recipes
    ''');
      await db.execute('DROP TABLE old_recipes');
      await db.execute('CREATE INDEX idx_recipes_category ON recipes (category)');
    }
    if (oldVersion < 5) {
      await db.execute('''
      ALTER TABLE recipes ADD COLUMN userId TEXT NOT NULL DEFAULT 'unknown'
    ''');
    }
  }

  // Add this new method for admin login
  Future<User?> getAdminUser(String email, String password) async {
    if (email == 'admin@gmail.com' && password == 'admin123') {
      // Check if admin already exists in database
      final existingAdmin = await getUser(email, password);
      if (existingAdmin != null) return existingAdmin;

      // Create new admin user if not exists
      final adminUser = User(
        id: 'admin-001',
        username: 'Admin',
        email: 'admin@gmail.com',
        password: 'admin123',
        isAdmin: true, createdAt: DateTime.now(),
      );
      await insertUser(adminUser);
      return adminUser;
    }
    return null;
  }
  // User operations
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUser(String email, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return result.isNotEmpty ? User.fromMap(result.first) : null;
  }

  Future<User?> getUserById(String userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    return result.isNotEmpty ? User.fromMap(result.first) : null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromMap(maps[i]));
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(String userId) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // Recipe operations
  Future<Recipe> insertRecipe(Recipe recipe) async {
    final db = await database;
    await db.insert('recipes', recipe.toMap());
    return recipe;
  }

  Future<List<Recipe>> getRecipes({
    String? query,
    String? category,
    String? userId,
    int? limit,
    int? offset
  }) async {
    final db = await database;

    String baseQuery = '''
    SELECT 
      recipes.*,
      COALESCE(AVG(user_ratings.rating), 0) AS averageRating,
      COUNT(user_ratings.rating) AS ratingCount
    FROM recipes
    LEFT JOIN user_ratings ON recipes.id = user_ratings.recipeId
  ''';

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClauses.add('userId = ?');
      whereArgs.add(userId);
    }

    if (query != null && query.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR description LIKE ?)');
      whereArgs.addAll(['%$query%', '%$query%']);
    }

    if (category != null && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    final String where = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final String groupBy = ' GROUP BY recipes.id';
    final String limitOffset = limit != null
        ? ' LIMIT $limit${offset != null ? ' OFFSET $offset' : ''}'
        : '';

    final String fullQuery = baseQuery + where + groupBy + limitOffset;

    final List<Map<String, dynamic>> maps = await db.rawQuery(fullQuery, whereArgs);

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return Recipe(
        id: map['id'].toString(), // Ensure ID is string
        title: map['title'].toString(),
        description: map['description'].toString(),
        category: map['category'].toString(),
        imageUrl: map['imageUrl'].toString(),
        ingredients: map['ingredients'].toString().split('||'),
        steps: map['steps'].toString().split('||'),
        userRatings: {}, // Will be populated separately
        videoUrl: map['videoUrl']?.toString(),
        userId: map['userId'].toString(),
        createdAt: DateTime.parse(map['createdAt'].toString()),
      );
    });
  }

  Future<Recipe> updateRecipe(Recipe recipe) async {
    final db = await database;
    await db.update(
      'recipes',
      recipe.toMap(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );
    return recipe;
  }

  Future<int> deleteRecipe(String recipeId) async {
    final db = await database;
    return await db.delete(
      'recipes',
      where: 'id = ?',
      whereArgs: [recipeId],
    );
  }
  Future<void> rateRecipe(String userId, String recipeId, double rating) async {
    final db = await database;
    await db.insert(
      'user_ratings',
      {
        'userId': userId,
        'recipeId': recipeId,
        'rating': rating,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserRating?> getUserRating(String userId, String recipeId) async {
    final db = await database;
    final results = await db.query(
      'user_ratings',
      where: 'userId = ? AND recipeId = ?',
      whereArgs: [userId, recipeId],
    );

    return results.isNotEmpty ? UserRating.fromMap(results.first) : null;
  }

  // Comment operations
  Future<int> insertComment(Comment comment) async {
    final db = await database;
    return await db.insert('comments', comment.toMap());
  }

  Future<int> addComment(Comment comment) async {
    return await insertComment(comment);
  }

  Future<List<Comment>> getComments(String recipeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'comments',
      where: 'recipeId = ?',
      whereArgs: [recipeId],
    );
    return List.generate(maps.length, (i) => Comment.fromMap(maps[i]));
  }

  Future<List<Comment>> getAllComments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('comments');
    return List.generate(maps.length, (i) => Comment.fromMap(maps[i]));
  }

  Future<int> deleteComment(String commentId) async {
    final db = await database;
    return await db.delete(
      'comments',
      where: 'id = ?',
      whereArgs: [commentId],
    );
  }

  // Favorite operations
  Future<bool> isFavorite(String userId, String recipeId) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'userId = ? AND recipeId = ?',
      whereArgs: [userId, recipeId],
    );
    return result.isNotEmpty;
  }

  Future<int> addFavorite(String userId, String recipeId) async {
    final db = await database;
    return await db.insert(
      'favorites',
      {'userId': userId, 'recipeId': recipeId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> removeFavorite(String userId, String recipeId) async {
    final db = await database;
    return await db.delete(
      'favorites',
      where: 'userId = ? AND recipeId = ?',
      whereArgs: [userId, recipeId],
    );
  }

  Future<List<Recipe>> getFavorites(String userId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT recipes.* FROM recipes
      INNER JOIN favorites ON recipes.id = favorites.recipeId
      WHERE favorites.userId = ?
    ''', [userId]);
    return List.generate(result.length, (i) => Recipe.fromMap(result[i]));
  }

  Future<void> insertSampleRecipes() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM recipes')
    ) ?? 0;

    if (count == 0) {
      await insertRecipe(Recipe(
        id: '1',
        title: 'Sushi Roll',
        description: 'Delicious homemade sushi',
        category: 'Main Dish',
        imageUrl: 'https://media.istockphoto.com/id/1354366250/fr/photo/ensemble-de-rouleaux-de-sushi-uramaki-arc-en-ciel-avec-avocat.jpg?s=612x612&w=0&k=20&c=5zCQXMzNHDT9vxcWOa_OzSU1OsrB6YgBgvhqSYvfsYc=',
        ingredients: ['Rice', 'Nori', 'Fish', 'Vegetables'],
        steps: ['Prepare rice', 'Add fillings', 'Roll tightly'],
        userRatings: {},
        videoUrl: 'https://youtu.be/JWZ5-9QiqQo',
        userId: 'admin-001',
        createdAt: DateTime.now(),
      ));

      await insertRecipe(Recipe(
        id: '2',
        title: 'Main Dish',
        description: 'Authentic Japanese ramen',
        category: 'Japanese',
        imageUrl: 'https://fooddiversity.today/wp-content/uploads/2024/09/IMG_2906-1440x1080.jpg',
        ingredients: ['Noodles', 'Broth', 'chicken', 'Eggs'],
        steps: ['Make broth', 'Cook noodles', 'Add toppings'],
        userRatings: {},
        videoUrl: 'https://www.youtube.com/watch?v=QWspNixyKKY',
        userId: 'admin-001',
        createdAt: DateTime.now(),
      ));
    }
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}