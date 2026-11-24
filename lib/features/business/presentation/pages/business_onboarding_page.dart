import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../data/business_repository.dart';
import '../../data/models/business.dart';
import '../../data/models/business_type.dart';
import '../../../auth/presentation/session_controller.dart';

/// Tunnel d'onboarding en 4 étapes (US-01) :
/// 1. Choix du type -> 2. Identité -> 3. Coordonnées -> 4. Récapitulatif.
/// À l'étape finale : POST /api/businesses/ (le backend crée rôles,
/// règles métier et membership OWNER dans une transaction).
class BusinessOnboardingPage extends StatefulWidget {
  const BusinessOnboardingPage({super.key});

  @override
  State<BusinessOnboardingPage> createState() => _BusinessOnboardingPageState();
}

class _BusinessOnboardingPageState extends State<BusinessOnboardingPage> {
  static const _steps = ['Type', 'Identité', 'Coordonnées', 'Récapitulatif'];

  int _step = 0;
  bool _loadingTypes = true;
  String? _typesError;
  List<BusinessType> _types = [];

  final _draft = BusinessDraft();
  String? _selectedType;

  final _nomController = TextEditingController();
  final _adresseController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nomKey = GlobalKey<FormState>();
  String? _createError;

  @override
  void initState() {
    super.initState();
    _nomController.addListener(_onDraftChanged);
    _loadTypes();
  }

  @override
  void dispose() {
    _nomController.removeListener(_onDraftChanged);
    _nomController.dispose();
    _adresseController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onDraftChanged() => setState(() {});

  Future<void> _loadTypes() async {
    setState(() {
      _loadingTypes = true;
      _typesError = null;
    });
    final repository = context.read<BusinessRepository>();
    try {
      final types = await repository.businessTypes();
      if (mounted) setState(() => _types = types);
    } on ApiException catch (e) {
      if (mounted) setState(() => _typesError = e.message);
    } finally {
      if (mounted) setState(() => _loadingTypes = false);
    }
  }

  bool get _canGoNext {
    switch (_step) {
      case 0:
        return _selectedType != null;
      case 1:
        return _nomController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (_step == 1 &&
        !(_nomKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _create();
    }
  }

  void _back() {
    if (_step == 0) {
      _confirmCancel();
    } else {
      setState(() => _step--);
    }
  }

  /// L'onboarding est la route racine : « Annuler » propose la déconnexion
  /// (retour à la page de connexion).
  Future<void> _confirmCancel() async {
    final session = context.read<SessionController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter la création ?'),
        content: const Text(
          'Votre session sera fermée et vous reviendrez à l\'écran de '
          'connexion. Les informations saisies seront perdues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Quitter',
              style: TextStyle(color: AppColors.dangerText),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await session.logout();
  }

  Future<void> _create() async {
    final session = context.read<SessionController>();
    setState(() => _createError = null);
    try {
      _draft
        ..businessType = _selectedType!
        ..nom = _nomController.text.trim()
        ..adresse = _adresseController.text.trim()
        ..telephone = _telephoneController.text.trim()
        ..email = _emailController.text.trim();
      await session.createBusiness(_draft);
    } on ApiException catch (e) {
      if (mounted) setState(() => _createError = e.message);
    } on NetworkUnavailableException catch (e) {
      if (mounted) setState(() => _createError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _createError =
            'Une erreur inattendue est survenue. Veuillez vérifier votre connexion.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Créer votre business')),
      body: SafeArea(
        child: Column(
          children: [
            _StepIndicator(current: _step, steps: _steps),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStep(context, session),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: OutlinedButton(
                      onPressed: session.busy ? null : _back,
                      child: Text(_step == 0 ? 'Annuler' : 'Retour'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: _step == 3 ? 'Valider & créer' : 'Suivant',
                      icon: _step == 3 ? Icons.check_circle_outline : null,
                      isLoading: session.busy,
                      onPressed: _canGoNext && !session.busy ? _next : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, SessionController session) {
    switch (_step) {
      case 0:
        return _buildTypeStep(context);
      case 1:
        return _buildIdentityStep();
      case 2:
        return _buildContactStep();
      default:
        return _buildRecapStep(context);
    }
  }

  // --- Étape 1 : Type de business ------------------------------------------

  Widget _buildTypeStep(BuildContext context) {
    if (_loadingTypes) {
      return Skeleton(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const SkeletonText(width: 90, height: 12),
            const SizedBox(height: 8),
            const SkeletonText(width: 220, height: 22),
            const SizedBox(height: 4),
            const SkeletonText(width: 260, height: 14),
            const SizedBox(height: 24),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SkeletonCard(
                  radius: 20,
                  child: Row(
                    children: const [
                      SkeletonBox(
                        width: 44,
                        height: 44,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      SizedBox(width: 14),
                      Expanded(child: SkeletonText(width: 140, height: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (_typesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.hint),
              const SizedBox(height: 12),
              Text(_typesError!, style: AppTextStyles.body),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: _loadTypes,
                  child: const Text('Réessayer'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text('Étape 1 sur 4', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        Text('Quel type de business ?', style: AppTextStyles.h1),
        const SizedBox(height: 4),
        Text('La configuration (rôles, modules) suivra ce choix.',
            style: AppTextStyles.body),
        const SizedBox(height: 24),
        ..._types.map((type) {
          final selected = _selectedType == type.codename;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TypeCard(
              type: type,
              selected: selected,
              onTap: () => setState(() => _selectedType = type.codename),
            ),
          );
        }),
      ],
    );
  }

  // --- Étape 2 : Identité ----------------------------------------------------

  Widget _buildIdentityStep() {
    return Form(
      key: _nomKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Text('Étape 2 sur 4', style: AppTextStyles.fieldLabel),
          const SizedBox(height: 8),
          Text('Identité du business', style: AppTextStyles.h1),
          const SizedBox(height: 4),
          Text('Comment vos clients et votre équipe vont-ils le voir ?',
              style: AppTextStyles.body),
          const SizedBox(height: 24),
          CustomInputField(
            label: 'Nom du business *',
            hint: 'Décoration Joël',
            prefixIcon: Icons.storefront_outlined,
            controller: _nomController,
            textInputAction: TextInputAction.next,
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Le nom est obligatoire'
                : null,
          ),
          const SizedBox(height: 20),
          Text('LOGO', style: AppTextStyles.fieldLabel),
          const SizedBox(height: 8),
          _LogoPicker(
            logoPath: _draft.logoPath,
            onPicked: (path) => setState(() {
              _draft.logoPath = path;
              _draft.logoUrl = '';
            }),
            onRemove: () => setState(() {
              _draft.logoPath = null;
              _draft.logoUrl = '';
            }),
          ),
          const SizedBox(height: 8),
          Text('Choisissez une image dans votre galerie (optionnel).',
              style: AppTextStyles.body),
        ],
      ),
    );
  }

  // --- Étape 3 : Coordonnées -------------------------------------------------

  Widget _buildContactStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text('Étape 3 sur 4', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        Text('Coordonnées', style: AppTextStyles.h1),
        const SizedBox(height: 4),
        Text('Où et comment vous joindre ?', style: AppTextStyles.body),
        const SizedBox(height: 24),
        CustomInputField(
          label: 'Adresse',
          hint: 'Lomé, Togo',
          prefixIcon: Icons.place_outlined,
          controller: _adresseController,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 20),
        CustomInputField(
          label: 'Téléphone',
          hint: '+228 97 77 77 77',
          prefixIcon: Icons.phone_outlined,
          controller: _telephoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 20),
        CustomInputField(
          label: 'Email',
          hint: 'contact@business.com',
          prefixIcon: Icons.mail_outline,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  // --- Étape 4 : Récapitulatif -----------------------------------------------

  Widget _buildRecapStep(BuildContext context) {
    final typeLibelle = _types
        .where((t) => t.codename == _selectedType)
        .map((t) => t.libelle)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text('Étape 4 sur 4', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        Text('Récapitulatif', style: AppTextStyles.h1),
        const SizedBox(height: 4),
        Text('Vérifiez les informations avant la création.',
            style: AppTextStyles.body),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _RecapRow(
                    label: 'Type',
                    value: typeLibelle ?? _selectedType ?? '—'),
                _RecapRow(label: 'Nom', value: _nomController.text.trim()),
                if (_draft.logoUrl.isNotEmpty)
                  _RecapRow(label: 'Logo', value: _draft.logoUrl),
                if (_draft.logoPath != null)
                  const _RecapRow(label: 'Logo', value: 'Image (galerie)'),
                if (_adresseController.text.trim().isNotEmpty)
                  _RecapRow(
                      label: 'Adresse', value: _adresseController.text.trim()),
                if (_telephoneController.text.trim().isNotEmpty)
                  _RecapRow(
                      label: 'Téléphone',
                      value: _telephoneController.text.trim()),
                if (_emailController.text.trim().isNotEmpty)
                  _RecapRow(
                      label: 'Email', value: _emailController.text.trim()),
              ],
            ),
          ),
        ),
        if (_createError != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _createError!,
              style: const TextStyle(
                  color: AppColors.dangerText, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'La création génère automatiquement les rôles, règles métier et '
          'votre poste de propriétaire (transaction côté serveur).',
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> steps;

  const _StepIndicator({required this.current, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: done || active
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < steps.length - 1) const SizedBox(width: 6),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final BusinessType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (type.codename) {
      case 'DECORATION_RENTAL':
        return Icons.chair_outlined;
      case 'GENERAL_INVENTORY':
        return Icons.inventory_2_outlined;
      default:
        return Icons.business_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.inputBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _icon,
                color: selected ? Colors.white : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(type.libelle, style: AppTextStyles.h2),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;

  const _RecapRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label.toUpperCase(), style: AppTextStyles.fieldLabel),
          ),
          Expanded(child: Text(value, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

/// Sélection du logo depuis la galerie avec aperçu.
class _LogoPicker extends StatelessWidget {
  final String? logoPath;
  final ValueChanged<String> onPicked;
  final VoidCallback onRemove;

  const _LogoPicker({
    required this.logoPath,
    required this.onPicked,
    required this.onRemove,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) onPicked(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final path = logoPath;
    if (path != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(path),
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 88,
                height: 88,
                color: AppColors.inputBackground,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.hint),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(140, 48),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Changer'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.dangerText),
                  tooltip: 'Retirer le logo',
                ),
              ],
            ),
          ),
        ],
      );
    }
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 32, color: AppColors.primary),
            SizedBox(height: 8),
            Text(
              'Choisir un logo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}