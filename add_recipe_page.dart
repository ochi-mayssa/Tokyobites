import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'recipe_model.dart';
import 'database_helper.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';

class AddRecipePage extends StatefulWidget {
  final Recipe? recipe;
  const AddRecipePage({this.recipe, Key? key}) : super(key: key);

  @override
  _AddRecipePageState createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isLoading = false;
  bool _isEditing = false;

  final List<String> _categories = [
    'All', 'Main Dish', 'Dessert', 'Soup', 'Appetizer'
  ];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  final _videoUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.recipe != null;
    if (_isEditing) _initializeFormWithRecipeData();
  }

  void _initializeFormWithRecipeData() {
    final recipe = widget.recipe!;
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description;
    _categoryController.text = recipe.category;
    _imageUrlController.text = recipe.imageUrl;
    _ingredientsController.text = recipe.ingredients.join('\n');
    _stepsController.text = recipe.steps.join('\n');
    _videoUrlController.text = recipe.videoUrl ?? '';
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageUrlController.clear();
        });
      }
    } catch (e) {
      _showErrorSnackbar('Failed to pick image: $e');
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.user?.id ?? 'unknown';

      final recipe = Recipe(
        id: widget.recipe?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        imageUrl: _imageFile != null
            ? _imageFile!.path
            : _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : 'https://via.placeholder.com/300x200?text=No+Image',
        ingredients: _ingredientsController.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        steps: _stepsController.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        userRatings: widget.recipe?.userRatings ?? {},
        videoUrl: _videoUrlController.text.trim(),
        userId: userId,
        createdAt: widget.recipe?.createdAt ?? DateTime.now(),
      );

      Recipe result;
      if (_isEditing) {
        result = await DatabaseHelper().updateRecipe(recipe);
      } else {
        result = await DatabaseHelper().insertRecipe(recipe);
      }

      Navigator.pop(context, result);
      _showSuccessSnackbar(_isEditing ? 'Recipe updated!' : 'Recipe added!');
    } catch (e) {
      _showErrorSnackbar('Error saving recipe: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Recipe' : 'Add Recipe',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: _confirmDelete,
            ),
        ],
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
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildImagePicker(),
                  SizedBox(height: 20),
                  _buildFormField(_titleController, 'Title', Icons.title, true),
                  _buildFormField(_descriptionController, 'Description', Icons.description, false, maxLines: 3),
                  _buildCategoryDropdown(),
                  if (_imageFile == null)
                    _buildFormField(_imageUrlController, 'Image URL', Icons.image, false),
                  _buildFormField(_ingredientsController, 'Ingredients (one per line)', Icons.list, true, maxLines: 5),
                  _buildFormField(_stepsController, 'Steps (one per line)', Icons.format_list_numbered, true, maxLines: 8),
                  _buildFormField(_videoUrlController, 'Video URL (optional)', Icons.video_library, false),
                  SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          image: _getImageDecoration(),
          border: Border.all(color: Colors.pinkAccent, width: 2),
        ),
        child: _imageFile == null && _imageUrlController.text.isEmpty
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 50, color: Colors.pinkAccent),
            Text(
              'Add Recipe Image',
              style: TextStyle(color: Colors.pinkAccent, fontSize: 16),
            ),
          ],
        )
            : null,
      ),
    );
  }

  DecorationImage? _getImageDecoration() {
    if (_imageFile != null) {
      return DecorationImage(
        image: FileImage(_imageFile!),
        fit: BoxFit.cover,
      );
    } else if (_imageUrlController.text.isNotEmpty) {
      return DecorationImage(
        image: NetworkImage(_imageUrlController.text),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Widget _buildFormField(
      TextEditingController controller,
      String label,
      IconData icon,
      bool required, {
        int maxLines = 1,
      }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.pinkAccent),
          filled: true,
          fillColor: Colors.black.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.pinkAccent, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red),
          ),
        ),
        maxLines: maxLines,
        validator: required ? (value) => value!.isEmpty ? 'This field is required' : null : null,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
        dropdownColor: Colors.black.withOpacity(0.9),
        style: TextStyle(color: Colors.white),
        items: _categories.map((String category) {
          return DropdownMenuItem<String>(
            value: category,
            child: Text(category, style: TextStyle(color: Colors.white)),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _categoryController.text = newValue ?? '';
          });
        },
        decoration: InputDecoration(
          labelText: 'Category',
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.category, color: Colors.pinkAccent),
          filled: true,
          fillColor: Colors.black.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.pinkAccent, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Please select a category' : null,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pinkAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        onPressed: _isLoading ? null : _saveRecipe,
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text(
          _isEditing ? 'Update Recipe' : 'Save Recipe',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        title: Text('Delete Recipe', style: TextStyle(color: Colors.pinkAccent)),
        content: Text('Are you sure you want to delete this recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.pinkAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _deleteRecipe();
  }

  Future<void> _deleteRecipe() async {
    setState(() => _isLoading = true);
    try {
      await DatabaseHelper().deleteRecipe(widget.recipe!.id);
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackbar('Error deleting recipe: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }
}