import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/items_repository.dart';

/// Création d'une catégorie du catalogue (US-05).
class NewCategoryPage extends StatefulWidget {
  const NewCategoryPage({super.key});

  @override
  State<NewCategoryPage> createState() => _NewCategoryPageState();
}

class _NewCategoryPageState extends State<NewCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  late final ItemsRepository _repository;
  late final Business _business;

  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool? _entretienRequis;
  bool _submitting = false;
  String? _error;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ItemsRepository>();
    _business = context.read<SessionController>().currentBusiness!;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final category = await _repository.createCategory(
        _business.id,
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim(),
        entretienRequis: _entretienRequis,
        image: _imagePath,
      );
      if (mounted) Navigator.of(context).pop(category);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: null,
        leadingWidth: 120,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 20),
          label: const Text('Inventaire'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ajouter une catégorie', style: AppTextStyles.h1),
                const SizedBox(height: 4),
                Text(
                  'Regroupez vos articles pour mieux organiser votre catalogue.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 32),
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
                Text('Image', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _showImageSourceDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.dashOutlineVariant),
                    ),
                    child: _imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_imagePath!),
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 48,
                                color: AppColors.dashOutline,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ajouter une image',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.dashOnSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '(optionnel)',
                                style: AppTextStyles.labelCaps.copyWith(
                                  color: AppColors.dashOutline,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_imagePath != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _imagePath = null),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer l\'image'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('ENTRETIEN REQUIS', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                DropdownButtonFormField<bool?>(
                  initialValue: _entretienRequis,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Non défini',
                    prefixIcon: Icon(
                      Icons.build_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Non défini (par défaut)'),
                    ),
                    DropdownMenuItem(value: true, child: Text('Oui')),
                    DropdownMenuItem(value: false, child: Text('Non')),
                  ],
                  onChanged: (value) =>
                      setState(() => _entretienRequis = value),
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
                        color: AppColors.dangerText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: PrimaryButton(
          label: 'Créer la catégorie',
          icon: Icons.add_box_outlined,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ),
    );
  }
}
