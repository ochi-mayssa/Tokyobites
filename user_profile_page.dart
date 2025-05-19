import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_model.dart';
import 'user_provider.dart';
import 'recipe_model.dart';
import 'database_helper.dart';
import 'add_recipe_page.dart';
import 'recipe_details_page.dart';

class UserProfilePage extends StatefulWidget {
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ImagePicker _picker = ImagePicker();
  List<Recipe> _userRecipes = [];
  List<Recipe> _favorites = [];
  bool _isLoading = true;
  bool _isEditing = false;
  File? _profileImage;
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _dbHelper.getRecipes(userId: userProvider.user!.id),
        _dbHelper.getFavorites(userProvider.user!.id)
      ]);

      setState(() {
        _userRecipes = results[0] as List<Recipe>;
        _favorites = results[1] as List<Recipe>;
        _isLoading = false;
        _usernameController.text = userProvider.user!.username;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading data: ${e.toString()}', isError: true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _profileImage = File(pickedFile.path));
        _showSnackBar('Profile image updated');
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}', isError: true);
    }
  }

  void _toggleEditMode() => setState(() => _isEditing = !_isEditing);

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) return;

    try {
      final updatedUser = userProvider.user!.copyWith(
        username: _usernameController.text,
        profileImage: _profileImage?.path ?? userProvider.user!.profileImage,
      );

      await _dbHelper.updateUser(updatedUser);
      userProvider.login(updatedUser);
      _toggleEditMode();
      _showSnackBar('Profile updated successfully');
    } catch (e) {
      _showSnackBar('Failed to update profile: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/food_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline, size: 60, color: Colors.pinkAccent),
                  const SizedBox(height: 20),
                  const Text(
                    'Please log in to view profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Login', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.pinkAccent, width: 2)),
                child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _getProfileImage(user)),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.pinkAccent,
                        shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                  user.username,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (user.isAdmin) _buildAdminBadge(),
            ],
          ),
        ],
      ),
    );
  }

  ImageProvider _getProfileImage(User user) {
    if (_profileImage != null) return FileImage(_profileImage!);
    if (user.profileImage != null && user.profileImage!.isNotEmpty) {
      if (user.profileImage!.startsWith('http')) {
        return CachedNetworkImageProvider(user.profileImage!);
      } else {
        return FileImage(File(user.profileImage!));
      }
    }
    return const AssetImage('assets/default_profile.png');
  }

  Widget _buildAdminBadge() {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/admin'),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.pinkAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.admin_panel_settings, size: 14, color: Colors.pinkAccent),
            SizedBox(width: 4),
            Text(
              'Admin',
              style: TextStyle(
                color: Colors.pinkAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileSection() {
    if (!_isEditing) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildEditableField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildReadOnlyEmailField(userEmail: Provider.of<UserProvider>(context).user!.email),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.pinkAccent),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.pinkAccent, width: 2)),
      ),
      validator: validator,
    );
  }

  Widget _buildReadOnlyEmailField({required String userEmail}) {
    return TextFormField(
      initialValue: userEmail,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email, color: Colors.pinkAccent),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildContentSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Colors.pinkAccent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeList(List<Recipe> recipes) {
    return _isLoading
        ? _buildLoadingIndicator()
        : recipes.isEmpty
        ? _buildEmptyState('No recipes yet. Tap + to add one!')
        : ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recipes.length,
      itemBuilder: (ctx, index) => _buildRecipeCard(recipes[index]),
    );
  }

  Widget _buildFavoriteList() {
    return _isLoading
        ? _buildLoadingIndicator()
        : _favorites.isEmpty
        ? _buildEmptyState('No favorites yet')
        : RefreshIndicator(
      onRefresh: _loadUserData,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _favorites.length,
        itemBuilder: (ctx, index) => _buildRecipeCard(_favorites[index]),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToRecipeDetails(recipe),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _buildRecipeImage(recipe),
            const SizedBox(width: 12),
            Expanded(child: _buildRecipeInfo(recipe)),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecipeImage(Recipe recipe) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 70,
        height: 70,
        color: Colors.grey[200],
        child: recipe.imageUrl.isNotEmpty
            ? recipe.imageUrl.startsWith('http')
            ? CachedNetworkImage(
          imageUrl: recipe.imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildImagePlaceholder(),
          errorWidget: (_, __, ___) => _buildImagePlaceholder(),
        )
            : Image.file(
          File(recipe.imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Center(child: Icon(Icons.fastfood, color: Colors.grey));
  }

  Widget _buildRecipeInfo(Recipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.category, size: 16, color: Colors.pinkAccent),
          const SizedBox(width: 4),
          Text(recipe.category, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          const Icon(Icons.star, size: 16, color: Colors.amber),
          const SizedBox(width: 4),
          Text(recipe.rating.toString(), style: TextStyle(color: Colors.grey[600])),
        ]),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        const Icon(Icons.info_outline, color: Colors.pinkAccent, size: 40),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(color: Colors.grey[600])),
      ]),
    );
  }

  Widget _buildAddRecipeButton() {
    return FloatingActionButton(
      backgroundColor: Colors.pinkAccent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add, color: Colors.white),
      onPressed: () async {
        final newRecipe = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddRecipePage()),
        );
        if (newRecipe != null) {
          setState(() => _userRecipes.insert(0, newRecipe));
        }
      },
    );
  }

  void _navigateToRecipeDetails(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailsPage(initialRecipe: recipe),
      ),
    ).then((_) => _loadUserData());
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    if (user == null) return _buildLoginPrompt();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (user.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.pushNamed(context, '/admin'),
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: _toggleEditMode,
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
            ),
        ],
      ),
      floatingActionButton: _isEditing ? null : _buildAddRecipeButton(),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/food_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
                _buildProfileHeader(user),
                _buildEditProfileSection(),
                _buildContentSection(
                  title: 'My Recipes',
                  icon: Icons.restaurant_menu,
                  content: _buildRecipeList(_userRecipes),
                ),
                _buildContentSection(
                  title: 'My Favorites',
                  icon: Icons.favorite,
                  content: _buildFavoriteList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}