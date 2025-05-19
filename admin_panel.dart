import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'database_helper.dart';
import 'user_model.dart';
import 'recipe_model.dart';
import 'comment_model.dart';
import 'add_recipe_page.dart';
import 'edit_recipe_page.dart';

class AdminPanel extends StatefulWidget {
  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Update floating button based on active tab
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: "Users"),
            Tab(icon: Icon(Icons.restaurant), text: "Recipes"),
            Tab(icon: Icon(Icons.comment), text: "Comments"),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/food_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUsersTab(),
              _buildRecipesTab(),
              _buildCommentsTab(),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // Dynamic FAB
  Widget? _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton(
          backgroundColor: Colors.pinkAccent,
          child: const Icon(Icons.add),
          onPressed: () => _showAddUserDialog(context),
        );
      case 1:
        return FloatingActionButton(
          backgroundColor: Colors.pinkAccent,
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddRecipePage()));
          },
        );
      default:
        return null;
    }
  }

  // Users Tab
  Widget _buildUsersTab() {
    return FutureBuilder<List<User>>(
      future: DatabaseHelper().getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(child: Text('No users found', style: TextStyle(color: Colors.white)));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.all(8),
              color: Colors.white.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                  backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                      ? user.profileImage!.startsWith('http')
                      ? CachedNetworkImageProvider(user.profileImage!)
                      : FileImage(File(user.profileImage!)) as ImageProvider
                      : const AssetImage('assets/default_profile.png'),
                ),
                title: Text(user.username),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.pinkAccent),
                      onPressed: () => _showEditUserDialog(context, user),
                    ),
                    if (!user.isAdmin)
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteUser(context, user.id),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Recipes Tab
  Widget _buildRecipesTab() {
    return FutureBuilder<List<Recipe>>(
      future: DatabaseHelper().getRecipes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
        }
        final recipes = snapshot.data ?? [];
        if (recipes.isEmpty) {
          return Center(child: Text('No recipes found', style: TextStyle(color: Colors.white)));
        }

        return ListView.builder(
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return Card(
              margin: const EdgeInsets.all(8),
              color: Colors.white.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: recipe.imageUrl.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    recipe.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.fastfood, color: Colors.pinkAccent),
                  ),
                )
                    : Icon(Icons.fastfood, color: Colors.pinkAccent),
                title: Text(recipe.title),
                subtitle: Text(recipe.category),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.pinkAccent),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditRecipePage(recipe: recipe)),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRecipe(context, recipe.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Comments Tab
  Widget _buildCommentsTab() {
    return FutureBuilder<List<Comment>>(
      future: DatabaseHelper().getAllComments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
        }
        final comments = snapshot.data ?? [];
        if (comments.isEmpty) {
          return Center(child: Text('No comments found', style: TextStyle(color: Colors.white)));
        }

        return ListView.builder(
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Card(
              margin: const EdgeInsets.all(8),
              color: Colors.white.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(comment.username),
                subtitle: Text(comment.content),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteComment(context, comment.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Dialogs
  Future<void> _showAddUserDialog(BuildContext context) async {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdmin = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          title: Text('Add New User', style: TextStyle(color: Colors.pinkAccent)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: Colors.pinkAccent),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.pinkAccent),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.pinkAccent),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text('Admin privileges', style: TextStyle(color: Colors.pinkAccent)),
                  value: isAdmin,
                  activeColor: Colors.pinkAccent,
                  onChanged: (val) => setState(() => isAdmin = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.pinkAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              onPressed: () async {
                if (usernameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final newUser = User(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  username: usernameController.text,
                  email: emailController.text,
                  password: passwordController.text,
                  isAdmin: isAdmin,
                  createdAt: DateTime.now(),
                );

                try {
                  await DatabaseHelper().insertUser(newUser);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User created successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(ctx);
                  setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditUserDialog(BuildContext context, User user) async {
    final usernameController = TextEditingController(text: user.username);
    final emailController = TextEditingController(text: user.email);
    bool isAdmin = user.isAdmin;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          title: Text('Edit User', style: TextStyle(color: Colors.pinkAccent)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: Colors.pinkAccent),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.pinkAccent),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text('Admin privileges', style: TextStyle(color: Colors.pinkAccent)),
                  value: isAdmin,
                  activeColor: Colors.pinkAccent,
                  onChanged: (val) => setState(() => isAdmin = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.pinkAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              onPressed: () async {
                if (usernameController.text.isEmpty || emailController.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final updatedUser = user.copyWith(
                  username: usernameController.text,
                  email: emailController.text,
                  isAdmin: isAdmin,
                );

                try {
                  await DatabaseHelper().updateUser(updatedUser);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User updated'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(ctx);
                  setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUser(BuildContext context, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        title: Text('Delete User?', style: TextStyle(color: Colors.pinkAccent)),
        content: Text('This action cannot be undone.', style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.pinkAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteUser(context, userId);
    }
  }

  Future<void> _deleteUser(BuildContext context, String userId) async {
    try {
      await DatabaseHelper().deleteUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User deleted'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteRecipe(BuildContext context, String recipeId) async {
    try {
      await DatabaseHelper().deleteRecipe(recipeId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recipe deleted'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteComment(BuildContext context, String commentId) async {
    try {
      await DatabaseHelper().deleteComment(commentId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comment deleted'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}