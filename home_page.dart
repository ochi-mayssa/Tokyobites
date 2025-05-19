import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:newapp/user_model.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'user_provider.dart';
import 'recipe_details_page.dart';
import 'database_helper.dart';
import 'recipe_model.dart';
import 'add_recipe_page.dart';
import 'user_profile_page.dart';
import 'edit_recipe_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  final List<VideoPlayerController> _videoControllers = [];

  List<Recipe> _recipes = [];
  bool _isLoading = false;
  bool _isError = false;
  int _offset = 0;
  final int _limit = 10;
  Timer? _searchDebounce;

  bool _isDarkMode = false;
  List<String> _categories = ['All', 'Main Dish', 'Dessert', 'Soup', 'Appetizer'];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _fetchRecipes();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    for (final controller in _videoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleFullScreen(BuildContext context) {
    final deviceOrientation = MediaQuery.of(context).orientation;
    SystemChrome.setPreferredOrientations([
      deviceOrientation == Orientation.portrait
          ? DeviceOrientation.landscapeRight
          : DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _fetchRecipes({String? query, String? category}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      final recipes = await _dbHelper.getRecipes(
        query: query,
        category: category == 'All' ? null : category,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        if (_offset == 0) {
          _recipes = recipes;
        } else {
          _recipes.addAll(recipes);
        }
        _offset += _limit;
      });
    } catch (e) {
      setState(() => _isError = true);
      _showSnackBar('Failed to fetch recipes: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.photo_camera, size: 50, color: Colors.grey[400]),
      ),
    );
  }

  Future<void> _navigateToEditRecipe(Recipe recipe) async {
    final updatedRecipe = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRecipePage(recipe: recipe),
      ),
    );

    if (updatedRecipe != null) {
      setState(() {
        final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);
        if (index != -1) {
          _recipes[index] = updatedRecipe;
        }
      });
    }
  }

  Future<void> _confirmDeleteRecipe(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Recipe'),
        content: Text('Are you sure you want to delete this recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteRecipe(recipe);
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    try {
      await _dbHelper.deleteRecipe(recipe.id);
      setState(() {
        _recipes.removeWhere((r) => r.id == recipe.id);
      });
      _showSnackBar('Recipe deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete recipe: $e');
    }
  }

  Widget _buildRecipeCard(Recipe recipe, ThemeData theme) {
    return FutureBuilder<User?>(
      future: _dbHelper.getUserById(recipe.userId),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return Padding(
          padding: EdgeInsets.all(8),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailsPage(initialRecipe: recipe),
                ),
              ).then((_) => setState(() {}));
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        child: Container(
                          height: 220,
                          width: double.infinity,
                          child: _buildMediaContent(recipe),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (user != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundImage: user.profileImage != null
                                      ? NetworkImage(user.profileImage!)
                                      : null,
                                  child: user.profileImage == null
                                      ? Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                  user.username,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    recipe.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.star, size: 16, color: Colors.amber),
                                    SizedBox(width: 4),
                                    Text(
                                      recipe.rating.toStringAsFixed(1), // Show 1 decimal place
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      ' (${recipe.userRatings.length})', // Show number of ratings
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                            SizedBox(height: 5),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: theme.colorScheme.secondary.withOpacity(0.1),
                              ),
                              child: Text(
                                recipe.category,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                            if (Provider.of<UserProvider>(context).user?.id == recipe.userId)
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 20),
                                    onPressed: () => _navigateToEditRecipe(recipe),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () => _confirmDeleteRecipe(recipe),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                        ),    ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: FutureBuilder<bool>(
                        future: _isFavorite(recipe),
                        builder: (context, snapshot) {
                          final isFavorite = snapshot.data ?? false;
                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + 0.2 * _animationController.value,
                                child: child,
                              );
                            },
                            child: IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : theme.colorScheme.onSurface,
                              ),
                              onPressed: () => _toggleFavorite(recipe),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaContent(Recipe recipe) {
    if (recipe.videoUrl?.isNotEmpty ?? false) {
      return _buildVideoPlayer(recipe.videoUrl!);
    }
    return _buildRecipeImage(recipe.imageUrl);
  }

  Widget _buildRecipeImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 150,
      placeholder: (context, url) => _buildSkeletonLoader(),
      errorWidget: (context, url, error) => _buildImagePlaceholder(),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    try {
      final videoId = _extractYoutubeId(videoUrl);
      if (videoId == null) {
        return _buildVideoErrorWidget(
          title: 'URL non valide',
          message: 'Format YouTube incorrect',
          videoUrl: videoUrl,
        );
      }

      final controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: true,
        ),
      );

      return YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressColors: ProgressBarColors(
          playedColor: Theme.of(context).colorScheme.secondary,
          handleColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    } catch (e) {
      return _buildVideoErrorWidget(
        title: 'Erreur technique',
        message: 'Impossible de charger la vidéo',
      );
    }
  }

  String? _extractYoutubeId(String url) {
    try {
      final cleanedUrl = url.trim();
      if (cleanedUrl.contains('youtube.com/watch?v=')) {
        return cleanedUrl.split('v=')[1].split('&')[0];
      } else if (cleanedUrl.contains('youtu.be/')) {
        return cleanedUrl.split('youtu.be/')[1].split('?')[0];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildVideoErrorWidget({
    required String title,
    required String message,
    String? videoUrl,
  }) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          )),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (videoUrl != null) ...[
            const SizedBox(height: 8),
            Text(
              'URL: ${videoUrl.length > 30 ? '${videoUrl.substring(0, 30)}...' : videoUrl}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _recipes.clear();
      _offset = 0;
    });
    await _fetchRecipes(query: _searchController.text, category: _selectedCategory);
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      _fetchRecipes(query: _searchController.text, category: _selectedCategory);
    }
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _recipes.clear();
        _offset = 0;
      });
      _fetchRecipes(query: query, category: _selectedCategory);
    });
  }

  Future<bool> _isFavorite(Recipe recipe) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) return false;
    return await _dbHelper.isFavorite(userProvider.user!.id, recipe.id);
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) {
      _showSnackBar('Please login to add favorites');
      return;
    }

    try {
      if (await _isFavorite(recipe)) {
        await _dbHelper.removeFavorite(userProvider.user!.id, recipe.id);
        _showSnackBar('Removed from favorites');
      } else {
        await _dbHelper.addFavorite(userProvider.user!.id, recipe.id);
        _showSnackBar('Added to favorites');
        _animationController.forward(from: 0.0);
      }
      setState(() {});
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  Future<void> _pickProfileImage() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      final updatedUser = userProvider.user!.copyWith(
        profileImage: imageFile.path,
      );

      await _dbHelper.updateUser(updatedUser);
      userProvider.login(updatedUser);
      setState(() {});
    }
  }

  Widget _buildFavoritesList() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final theme = Theme.of(context);

    return FutureBuilder<List<Recipe>>(
      future: _dbHelper.getFavorites(userProvider.user!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.favorite_border,
            title: 'No favorites yet',
            description: 'Tap the heart icon to add recipes to your favorites',
            action: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Browse Recipes'),
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(16),
          physics: BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final recipe = snapshot.data![index];
            return _buildRecipeCard(recipe, theme);
          },
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    IconData? icon,
    String? title,
    String? description,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.search_off,
              size: 60,
              color: theme.colorScheme.secondary.withOpacity(0.7),
            ),
            SizedBox(height: 20),
            Text(
              title ?? 'No results found',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            if (description != null) ...[
              SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.redAccent,
          ),
          SizedBox(height: 16),
          Text(
            'Failed to load recipes',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.redAccent,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Retry',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      height: 20,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Spacer(),
                    Container(
                      height: 16,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : 'All';
                  _recipes.clear();
                  _offset = 0;
                  _fetchRecipes(query: _searchController.text, category: _selectedCategory);
                });
              },
              selectedColor: Theme.of(context).colorScheme.secondary,
              labelStyle: TextStyle(
                color: _selectedCategory == category
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userProvider = Provider.of<UserProvider>(context);

    return Theme(
      data: _isDarkMode
          ? ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          secondary: Colors.orangeAccent,
          surface: Colors.grey[850]!,
        ),
      )
          : ThemeData.light().copyWith(
        colorScheme: ColorScheme.light(
          secondary: Colors.deepOrange,
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                displacement: 40,
                color: Theme.of(context).colorScheme.secondary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                strokeWidth: 3,
                onRefresh: _refreshData,
                child: CustomScrollView(
                  physics: BouncingScrollPhysics(),
                  controller: _scrollController,
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 220,
                      flexibleSpace: LayoutBuilder(
                        builder: (context, constraints) {
                          final opacity = (constraints.maxHeight - kToolbarHeight) / (220 - kToolbarHeight);
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/images/japanese_header.jpg'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.6 * opacity),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Center(
                                child: Opacity(
                                  opacity: opacity,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'TokyoBites',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28 * (0.8 + 0.2 * opacity),
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Découvrez des saveurs authentiques',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8 * opacity),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      pinned: true,
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      elevation: 4,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
                          onPressed: _toggleDarkMode,
                          tooltip: 'Toggle Dark Mode',
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: AnimatedScale(
                          scale: _searchController.text.isEmpty ? 1.0 : 1.02,
                          duration: Duration(milliseconds: 200),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Rechercher une recette...',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                                  : null,
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.secondary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverToBoxAdapter(
                        child: _buildCategoryFilter(),
                      ),
                    ),
                    if (_isError)
                      SliverFillRemaining(
                        child: _buildErrorState(),
                      )
                    else if (_recipes.isEmpty && !_isLoading)
                      SliverFillRemaining(
                        child: _buildEmptyState(
                          icon: Icons.fastfood,
                          title: 'Aucune recette trouvée',
                          description: 'Essayez une autre recherche ou ajoutez une nouvelle recette',
                          action: userProvider.user?.isAdmin ?? false
                              ? ElevatedButton(
                            onPressed: () async {
                              final newRecipe = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddRecipePage(),
                                ),
                              );
                              if (newRecipe != null) {
                                setState(() {
                                  _recipes.insert(0, newRecipe);
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text('Add New Recipe'),
                          )
                              : null,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              if (index >= _recipes.length) {
                                return _isLoading
                                    ? _buildSkeletonLoader()
                                    : SizedBox.shrink();
                              }
                              final recipe = _recipes[index];
                              return _buildRecipeCard(recipe, Theme.of(context));
                            },
                            childCount: _recipes.length + (_isLoading ? 1 : 0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    if (userProvider.user == null) {
                      return FloatingActionButton(
                        mini: true,
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: Icon(Icons.login, color: Colors.white),
                        tooltip: 'Login',
                      );
                    }
                    return Tooltip(
                      message: 'User menu',
                      child: PopupMenuButton<String>(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.secondary,
                                Colors.deepPurple,
                              ],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            child: ClipOval(
                              child: userProvider.user!.profileImage != null
                                  ? CachedNetworkImage(
                                imageUrl: userProvider.user!.profileImage!,
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                                placeholder: (context, url) => Icon(Icons.person, color: Colors.white),
                                errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.white),
                              )
                                  : Icon(Icons.person, color: Colors.white),
                            ),
                          ),
                        ),
                        onSelected: (value) async {
                          switch (value) {
                            case 'profile':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfilePage(),
                                ),
                              );
                              break;
                            case 'favorites':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      title: Text('My Favorites'),
                                      backgroundColor: Theme.of(context).colorScheme.secondary,
                                    ),
                                    body: _buildFavoritesList(),
                                  ),
                                ),
                              );
                              break;
                            case 'change_photo':
                              await _pickProfileImage();
                              break;
                            case 'logout':
                              userProvider.logout();
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person, color: Theme.of(context).colorScheme.secondary),
                                SizedBox(width: 8),
                                Text('Profile'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'favorites',
                            child: Row(
                              children: [
                                Icon(Icons.favorite, color: Theme.of(context).colorScheme.secondary),
                                SizedBox(width: 8),
                                Text('Favorites'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'change_photo',
                            child: Row(
                              children: [
                                Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.secondary),
                                SizedBox(width: 8),
                                Text('Change Photo'),
                              ],
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Logout'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: userProvider.user != null && userProvider.user!.isAdmin
            ? TweenAnimationBuilder(
          tween: Tween(begin: 0.95, end: 1.05),
          duration: Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: FloatingActionButton(
            onPressed: () async {
              final newRecipe = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddRecipePage(),
                ),
              );
              if (newRecipe != null) {
                setState(() {
                  _recipes.insert(0, newRecipe);
                });
              }
            },
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: Icon(Icons.add, color: Colors.white),
            tooltip: 'Add new recipe',
          ),
        )
            : null,
      ),
    );
  }
}

extension on YoutubePlayerValue {
  get errorDescription => null;
}