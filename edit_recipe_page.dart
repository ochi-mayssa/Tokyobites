import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'database_helper.dart';
import 'recipe_model.dart';

class EditRecipePage extends StatefulWidget {
  final Recipe recipe;
  const EditRecipePage({required this.recipe, Key? key}) : super(key: key);

  @override
  _EditRecipePageState createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _ingredientsController;
  late TextEditingController _stepsController;
  late TextEditingController _categoryController;
  late TextEditingController _imageUrlController;
  late TextEditingController _videoUrlController;
  bool _isLoading = false;
  File? _imageFile;
  bool _isImageFromGallery = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.recipe.title);
    _descriptionController = TextEditingController(text: widget.recipe.description);
    _ingredientsController = TextEditingController(text: widget.recipe.ingredients.join('\n'));
    _stepsController = TextEditingController(text: widget.recipe.steps.join('\n'));
    _categoryController = TextEditingController(text: widget.recipe.category);
    _imageUrlController = TextEditingController(text: widget.recipe.imageUrl);
    _videoUrlController = TextEditingController(text: widget.recipe.videoUrl ?? '');
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isImageFromGallery = true;
        _imageUrlController.text = pickedFile.path;
      });
    }
  }

  Future<void> _updateRecipe() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final updatedRecipe = widget.recipe.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _categoryController.text,
          imageUrl: _imageUrlController.text,
          ingredients: _ingredientsController.text.split('\n').map((e) => e.trim()).toList(),
          steps: _stepsController.text.split('\n').map((e) => e.trim()).toList(),
          videoUrl: _videoUrlController.text.isEmpty ? null : _videoUrlController.text,
        );

        await DatabaseHelper().updateRecipe(updatedRecipe);
        Navigator.pop(context, updatedRecipe);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating recipe: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildImagePreview() {
    if (_imageFile != null) {
      return Image.file(
        _imageFile!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (widget.recipe.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.recipe.imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.white.withOpacity(0.3),
          child: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.white.withOpacity(0.3),
          child: Center(child: Icon(Icons.error, color: Colors.pinkAccent)),
        ),
      );
    } else {
      return Container(
        height: 200,
        color: Colors.white.withOpacity(0.3),
        child: Center(child: Icon(Icons.image, size: 50, color: Colors.pinkAccent)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Edit Recipe',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _updateRecipe,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Preview and Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recipe Image',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildImagePreview(),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.pinkAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Form Fields
                  _buildFormField(_titleController, 'Title', Icons.title, true),
                  SizedBox(height: 16),
                  _buildFormField(_descriptionController, 'Description', Icons.description, false, maxLines: 3),
                  SizedBox(height: 16),
                  _buildFormField(_categoryController, 'Category', Icons.category, true),
                  SizedBox(height: 16),
                  _buildFormField(_ingredientsController, 'Ingredients (one per line)', Icons.list, true, maxLines: 5),
                  SizedBox(height: 16),
                  _buildFormField(_stepsController, 'Steps (one per line)', Icons.format_list_numbered, true, maxLines: 8),
                  SizedBox(height: 16),
                  _buildFormField(_videoUrlController, 'Video URL (optional)', Icons.video_library, false),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _updateRecipe,
                      child: Text(
                        'SAVE CHANGES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(
      TextEditingController controller,
      String label,
      IconData icon,
      bool required, {
        int maxLines = 1,
      }) {
    return TextFormField(
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
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }
}