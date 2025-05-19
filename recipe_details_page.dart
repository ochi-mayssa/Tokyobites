import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'add_recipe_page.dart';
import 'recipe_model.dart';
import 'comment_model.dart';
import 'database_helper.dart';
import 'user_provider.dart';

class RecipeDetailsPage extends StatefulWidget {
  final Recipe initialRecipe;

  const RecipeDetailsPage({required this.initialRecipe});

  @override
  _RecipeDetailsPageState createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  late Recipe _recipe;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isFavorite = false;
  bool _loadingComments = true;
  bool _isVideoPlaying = false;
  double? _userRating;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _recipe = widget.initialRecipe;
    _initializeVideo();
    _loadData();
    _preloadImage();
  }

  Future<void> _preloadImage() async {
    if (_recipe.imageUrl.isNotEmpty && _recipe.imageUrl.startsWith('http')) {
      try {
        await precacheImage(
          CachedNetworkImageProvider(_recipe.imageUrl),
          context,
        );
      } catch (e) {
        debugPrint('Image preloading error: $e');
      }
    }
  }

  Future<void> _loadData() async {
    await _loadComments();
    await _checkFavorite();
    await _loadUserRating();
  }

  Future<void> _loadUserRating() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      final rating = await DatabaseHelper().getUserRating(user.id, _recipe.id);
      setState(() => _userRating = rating?.rating);
    }
  }

  Future<void> _rateRecipe(double rating) async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      // Show login prompt
      return;
    }

    try {
      await DatabaseHelper().rateRecipe(user.id, _recipe.id, rating);

      // Update local state
      setState(() {
        _userRating = rating;
        _recipe = _recipe.copyWith(
          userRatings: {..._recipe.userRatings, user.id: rating},
        );
      });

      // Show success message
    } catch (e) {
      // Show error message
    }
  }

  Future<void> _initializeVideo() async {
    if (_recipe.videoUrl != null && _recipe.videoUrl!.isNotEmpty) {
      try {
        _videoController = VideoPlayerController.network(_recipe.videoUrl!)
          ..initialize().then((_) {
            setState(() {
              _chewieController = ChewieController(
                videoPlayerController: _videoController!,
                autoPlay: false,
                looping: false,
                allowFullScreen: true,
                aspectRatio: _videoController!.value.aspectRatio,
                showControls: true,
                materialProgressColors: ChewieProgressColors(
                  playedColor: Theme.of(context).primaryColor,
                  handleColor: Theme.of(context).primaryColor,
                  bufferedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                  backgroundColor: Colors.grey.withOpacity(0.3),
                ),
              );
            });
          });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      _comments = await DatabaseHelper().getComments(_recipe.id);
    } finally {
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _checkFavorite() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      final isFav = await DatabaseHelper().isFavorite(user.id, _recipe.id);
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please login to favorite recipes'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    try {
      if (_isFavorite) {
        await DatabaseHelper().removeFavorite(user.id, _recipe.id);
      } else {
        await DatabaseHelper().addFavorite(user.id, _recipe.id);
      }
      setState(() => _isFavorite = !_isFavorite);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating favorite: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }





  Future<void> _addComment() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || _commentController.text.isEmpty) return;

    try {
      final comment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        recipeId: _recipe.id,
        userId: user.id,
        username: user.username,
        content: _commentController.text,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper().addComment(comment);
      _commentController.clear();
      await _loadComments();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add comment: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildImageSection() {
    return Hero(
      tag: 'recipe-image-${_recipe.id}',
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: _recipe.imageUrl.isNotEmpty
            ? _recipe.imageUrl.startsWith('http')
            ? CachedNetworkImage(
          imageUrl: _recipe.imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildImagePlaceholder(),
          errorWidget: (context, url, error) => _buildImagePlaceholder(),
        )
            : Image.file(
          File(_recipe.imageUrl),
          fit: BoxFit.cover,
        )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No Image Available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    if (_chewieController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Rate this recipe'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your rating:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Row(
                children: List.generate(5, (index) {
                  final ratingValue = index + 1;
                  return IconButton(
                    icon: Icon(
                      _userRating != null && ratingValue <= _userRating!
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 30,
                    ),
                    onPressed: () => _rateRecipe(ratingValue.toDouble()),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Average rating: ${_recipe.rating.toStringAsFixed(1)} (${_recipe.userRatings.length} ratings)',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        _recipe.description,
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }

  Widget _buildIngredients() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _recipe.ingredients.map((ingredient) => Chip(
          label: Text(ingredient),
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          labelStyle: TextStyle(
            color: Theme.of(context).primaryColor,
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _recipe.steps.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${entry.key + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final user = Provider.of<UserProvider>(context).user;
    final canDelete = user?.isAdmin == true || user?.id == comment.userId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    comment.username.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    comment.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _confirmDeleteComment(comment),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.content),
            const SizedBox(height: 8),
            Text(
              '${comment.createdAt.day}/${comment.createdAt.month}/${comment.createdAt.year}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper().deleteComment(comment.id);
      await _loadComments();
    }
  }

  Widget _buildCommentSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Comments'),
          _loadingComments
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
              ? const Center(
            child: Column(
              children: [
                Icon(Icons.comment, size: 50, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'No comments yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          )
              : Column(children: _comments.map(_buildCommentItem).toList()),
          if (Provider.of<UserProvider>(context).user != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                suffixIcon: IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  onPressed: _addComment,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _addComment(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final isOwner = user?.id == _recipe.userId;
    final isAdmin = user?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_recipe.title),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
          if (isOwner || isAdmin)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () async {
                final updatedRecipe = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddRecipePage(recipe: _recipe),
                  ),
                );
                if (updatedRecipe != null) {
                  setState(() {
                    _recipe = updatedRecipe;
                    _videoController?.dispose();
                    _chewieController?.dispose();
                    _initializeVideo();
                    _preloadImage();
                  });
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(),
            _buildVideoSection(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _recipe.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _recipe.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' (${_recipe.userRatings.length})',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _recipe.category,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildRatingSection(),
            _buildSectionTitle('Description'),
            _buildDescription(),
            _buildSectionTitle('Ingredients'),
            _buildIngredients(),
            _buildSectionTitle('Steps'),
            _buildSteps(),
            _buildCommentSection(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    _commentController.dispose();
    super.dispose();
  }
}