import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'recipe_model.dart';
import 'user_model.dart';
import 'user_provider.dart';
import 'recipe_provider.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final recipeProvider = Provider.of<RecipeProvider>(context);

    if (!userProvider.user!.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('Accès refusé')),
        body: Center(child: Text('Vous n\'avez pas les droits d\'administration')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Panneau d\'administration'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.people)),
            Tab(icon: Icon(Icons.restaurant)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(userProvider),
          _buildRecipesList(recipeProvider),
        ],
      ),
    );
  }

  Widget _buildUsersList(UserProvider userProvider) {
    return FutureBuilder<List<User>>(
      future: userProvider.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur de chargement'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final user = snapshot.data![index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(user.email[0].toUpperCase()),
              ),
              title: Text(user.email),
              subtitle: Text(user.isAdmin ? 'Admin' : 'Utilisateur'),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _confirmUserDelete(user, userProvider),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecipesList(RecipeProvider recipeProvider) {
    return FutureBuilder<List<Recipe>>(
      future: recipeProvider.getAllRecipes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur de chargement'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final recipe = snapshot.data![index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(recipe.imageUrl),
              ),
              title: Text(recipe.title),
              subtitle: Text(recipe.category),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _confirmRecipeDelete(recipe, recipeProvider),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmUserDelete(User user, UserProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer l\'utilisateur ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${user.email} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteUser(user.id);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmRecipeDelete(Recipe recipe, RecipeProvider provider) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('Supprimer la recette ?'),
            content: Text(
                'Êtes-vous sûr de vouloir supprimer "${recipe.title}" ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  await provider.deleteRecipe(recipe.id);
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
