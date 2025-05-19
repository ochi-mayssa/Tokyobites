import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_panel.dart';
import 'user_provider.dart';
import 'recipe_provider.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'admin_page.dart';
import 'user_profile_page.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final dbHelper = DatabaseHelper();
    await dbHelper.insertSampleRecipes();
    runApp(MyApp());
  } catch (e) {
    print('Failed to initialize database: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize app. Please try again later.'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
      ],
      child: MaterialApp(
        title: 'Recipe App',
        theme: ThemeData(
          primarySwatch: Colors.deepOrange,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => HomePage(),
          '/login': (context) => LoginPage(),
          '/register': (context) => RegisterPage(),
          '/admin': (context) => AdminPanel(),
          '/profile': (context) => UserProfilePage(),
        },
      ),
    );
  }
}