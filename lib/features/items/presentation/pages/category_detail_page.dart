import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/items_repository.dart';
import '../../data/models/category.dart';
import '../../utils/category_images.dart';

/// Détail et édition d'une catégorie.
class CategoryDetailPage extends StatefulWidget {
  final String categoryId;

  const CategoryDetailPage({super.key, required this.categoryId});

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late final ItemsRepository _repository;
  late final Business _business;

  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool? _entretienRequis;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _imagePath;
  CategoryModel? _category;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ItemsRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _load();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await _repository.categories(_business.id);
      final category = categories.firstWhere(
        (c) => c.id == widget.categoryId,
        orElse: () => throw Exception('Catégorie introuvable'),
      );
      if (mounted) {
        setState(() {
          _category = category;
          _nomController.text = category.nom;
          _descriptionController.text = ''; // Description not in model yet
          _imagePath = category.image;
        });
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      return picked?.path;
    } on Exception {
      if (mounted) {
        _showSnackBar(
          source == ImageSource.camera
              ? 'Appareil photo indisponible. Autorisez-le dans les réglages ou choisissez une photo dans la galerie.'
              : 'Impossible d\'ouvrir la galerie.',
        );
      }
      return null;
    }
  }

  Future<void> _showImageSourceDialog() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      final path = await _pickImage(source);
      if (path != null && mounted) setState(() => _imagePath = path);
    }
  }

  Future<void> _deleteImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'image'),
        content: const Text('Voulez-vous vraiment supprimer l\'image de cette catégorie ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _imagePath = null);
    }
  }

  Widget _buildImagePreview(String categoryName) {
    final imageUrl = CategoryImages.getCategoryImage(
      localImage: _imagePath,
      categoryName: categoryName,
    );
    final isLocal = CategoryImages.isLocalImage(_imagePath);

    if (isLocal) {
      return Image.file(
        File(imageUrl),
        width: 160,
        height: 160,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      width: 160,
      height: 160,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
            color: AppColors.dashPrimary,
          ),
        );
      },
      errorBuilder: (_, __, ___) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined,
              size: 56, color: AppColors.dashPrimary),
          const SizedBox(height: 8),
          Text(
            'Toucher pour ajouter\nune image',
            textAlign: TextAlign.center,
            style: AppTextStyles.body
                .copyWith(color: AppColors.dashOnSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await _repository.updateCategory(
        _business.id,
        _category!.id,
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim(),
        entretienRequis: _entretienRequis,
        image: _imagePath,
      );
      if (mounted) {
        Navigator.of(context).pop(updated);
        _showSnackBar('Catégorie « ${updated.nom} » modifiée.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteCategory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text(
          'Voulez-vous vraiment supprimer la catégorie « ${_category?.nom} » ? '
          'Les articles qui l\'utilisent n\'auront plus de catégorie.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && _category != null && mounted) {
      // TODO: implémenter la suppression quand l'API le supporte
      _showSnackBar('Suppression non implémentée côté backend.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Catégorie')),
        body: Skeleton(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SkeletonCard(
                padding: EdgeInsets.all(16),
                radius: 16,
                child: SkeletonListItem(),
              ),
              SizedBox(height: 16),
              SkeletonCard(
                padding: EdgeInsets.all(16),
                radius: 16,
                child: SkeletonListItem(),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && _category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Catégorie')),
        body: _LoadError(message: _error!, onRetry: _load),
      );
    }

    final category = _category!;

    return Scaffold(
      backgroundColor: AppColors.dashSurfaceLow,
      appBar: AppBar(
        backgroundColor: AppColors.dashSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          category.nom,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dashPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Supprimer',
            onPressed: _deleteCategory,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image de la catégorie — champ dédié avec image réelle
                Text('Image de la catégorie', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                Center(
                  child: InkWell(
                    onTap: _showImageSourceDialog,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.dashOutlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildImagePreview(category.nom),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Wrap(
                    spacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(_imagePath == null ? 'Ajouter une image' : 'Modifier l\'image'),
                      ),
                      if (_imagePath != null)
                        TextButton.icon(
                          onPressed: _deleteImage,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Supprimer'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _imagePath == null
                        ? 'Aucune image enregistrée — un placeholder est affiché.'
                        : CategoryImages.isLocalImage(_imagePath)
                            ? 'Image locale non synchronisée — sera envoyée au serveur.'
                            : 'Image réelle enregistrée pour cette catégorie.',
                    style: AppTextStyles.labelCaps.copyWith(color: AppColors.dashOutline),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                Text('Informations', style: AppTextStyles.h2),
                const SizedBox(height: 16),
                CustomInputField(
                  label: 'Nom *',
                  hint: 'Coutellerie',
                  prefixIcon: Icons.category_outlined,
                  controller: _nomController,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Le nom est requis';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CustomInputField(
                  label: 'Description',
                  hint: 'Description optionnelle',
                  prefixIcon: Icons.notes_outlined,
                  controller: _descriptionController,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                Text('ENTRETIEN REQUIS', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                DropdownButtonFormField<bool?>(
                  initialValue: _entretienRequis,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Non défini',
                    prefixIcon: Icon(Icons.build_outlined,
                        color: Colors.grey, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: null, child: Text('Non défini (par défaut)')),
                    DropdownMenuItem(value: true, child: Text('Oui')),
                    DropdownMenuItem(value: false, child: Text('Non')),
                  ],
                  onChanged: (value) => setState(() => _entretienRequis = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.dangerText, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Enregistrer les modifications',
                  icon: Icons.save_outlined,
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                Text(
                  'Les articles utilisant cette catégorie verront les modifications après synchronisation.',
                  style: AppTextStyles.labelCaps.copyWith(color: AppColors.dashOutline),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.dangerText),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}