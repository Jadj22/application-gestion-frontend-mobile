import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/offline/offline_repository.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../session_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  Future<void> _openRegisterSheet() async {
    final session = context.read<SessionController>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ChangeNotifierProvider.value(
        value: session,
        child: const _RegisterFormSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryDark.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: session.busy
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('DODOME', style: AppTextStyles.wordmark),
                  const Spacer(),
                  Text(
                    'Rejoignez\nvotre inventaire',
                    style: AppTextStyles.display,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Créez votre compte en quelques secondes pour gérer votre stock B2B.',
                    style: AppTextStyles.body.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: AppDecorations.glassPanel(),
                    child: PrimaryButton(
                      label: 'Créer mon compte avec email',
                      variant: PrimaryButtonVariant.inverse,
                      isLoading: false,
                      onPressed: session.busy ? null : _openRegisterSheet,
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: TextButton(
                      onPressed: session.busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Déjà un compte ? Se connecter',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterFormSheet extends StatefulWidget {
  const _RegisterFormSheet();

  @override
  State<_RegisterFormSheet> createState() => _RegisterFormSheetState();
}

class _RegisterFormSheetState extends State<_RegisterFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final session = context.read<SessionController>();
    try {
      await session.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        telephone: _phoneController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } on OfflineUnsupportedException catch (e) {
      // L'inscription cree un compte cote serveur : hors ligne, on le dit
      // clairement plutot que de fabriquer un compte local inexistant.
      if (mounted) setState(() => _error = e.message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Créer un compte',
                  style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quelques informations pour commencer.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: CustomInputField(
                        label: 'Prénom',
                        hint: 'Prénom',
                        prefixIcon: Icons.person_outline,
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomInputField(
                        label: 'Nom',
                        hint: 'Nom de famille',
                        prefixIcon: Icons.person_outline,
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  label: 'Adresse email',
                  hint: 'vous@exemple.com',
                  prefixIcon: Icons.mail_outline,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'L\'email est requis';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  label: 'Téléphone (optionnel)',
                  hint: '+229 01 23 45 67',
                  prefixIcon: Icons.phone_outlined,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  label: 'Mot de passe',
                  hint: '8 caractères minimum',
                  prefixIcon: Icons.lock_outline,
                  controller: _passwordController,
                  isPassword: _obscure,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (value) {
                    if ((value ?? '').length < 8) {
                      return '8 caractères minimum';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInputField(
                  label: 'Confirmation',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  controller: _confirmController,
                  isPassword: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'Les mots de passe ne correspondent pas'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Créer mon compte',
                  icon: Icons.person_add_alt_1,
                  isLoading: session.busy,
                  onPressed: session.busy ? null : _submit,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerText.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.dangerText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.dangerText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
