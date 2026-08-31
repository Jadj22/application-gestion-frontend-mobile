import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/auth_repository.dart';
import '../session_controller.dart';

/// Acceptation d'une invitation par lien (Sprint 10) ou par code (Sprint 11).
/// L'utilisateur arrive depuis le lien de l'email (deep link) ou saisit
/// le code manuellement, choisit son mot de passe puis est connecte
/// immediatement grace aux JWT renvoyes par /invitations/accept/.
class AcceptInvitationPage extends StatefulWidget {
  /// Token signe (deep link, Sprint 10) - optionnel si code est fourni.
  final String? token;

  /// Code d'invitation (Sprint 11) - optionnel si token est fourni.
  final String? code;

  final VoidCallback onAccepted;
  final VoidCallback onCancel;

  const AcceptInvitationPage({
    super.key,
    this.token,
    this.code,
    required this.onAccepted,
    required this.onCancel,
  }) : assert(token != null || code != null, 'token ou code requis');

  @override
  State<AcceptInvitationPage> createState() => _AcceptInvitationPageState();
}

class _AcceptInvitationPageState extends State<AcceptInvitationPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  InvitationPreview? _preview;
  String? _loadError;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = context.read<AuthRepository>();
    try {
      if (widget.token != null) {
        // Deep link : apercu par token
        final preview = await repository.invitationPreview(widget.token!);
        if (mounted) setState(() => _preview = preview);
      } else if (widget.code != null) {
        // Code : validation et conversion en preview
        final validation = await repository.validateCode(widget.code!);
        if (mounted) {
          setState(() {
            _preview = InvitationPreview(
              email: validation.email,
              businessId: validation.businessId,
              businessNom: validation.businessNom,
              inviteur: validation.inviteur,
              role: validation.role,
              statut: 'INVITE',
            );
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = widget.token != null
            ? 'Lien d\'invitation invalide.'
            : 'Code d\'invitation invalide.');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final session = context.read<SessionController>();
    try {
      await session.acceptInvitation(
        token: widget.token,
        code: widget.code,
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      widget.onAccepted();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.mail_lock, size: 36, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Invitation',
                  textAlign: TextAlign.center, style: AppTextStyles.h1),
              const SizedBox(height: 6),
              if (_preview != null) ...[
                Text(
                  'Vous êtes invité(e) à rejoindre ${_preview!.businessNom} '
                  '${_preview!.role != null ? 'en tant que ${_preview!.role}' : ''}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 4),
                Text(
                  'Invitation pour ${_preview!.email}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
              ],
              if (_loadError != null) ...[
                const SizedBox(height: 24),
                _buildError(_loadError!),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Retour',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
              if (_preview != null) ...[
                const SizedBox(height: 32),
                Text('Créez votre mot de passe',
                    style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomInputField(
                        label: 'Mot de passe *',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline,
                        controller: _passwordController,
                        isPassword: _obscure,
                        textInputAction: TextInputAction.next,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        validator: (value) {
                          final v = value ?? '';
                          if (v.length < 8) {
                            return 'Au moins 8 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      CustomInputField(
                        label: 'Confirmez le mot de passe *',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline,
                        controller: _confirmController,
                        isPassword: _obscure,
                        textInputAction: TextInputAction.next,
                        validator: (value) => value != _passwordController.text
                            ? 'Les mots de passe ne correspondent pas'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: CustomInputField(
                              label: 'Prénom (optionnel)',
                              hint: 'Kossi',
                              prefixIcon: Icons.person_outline,
                              controller: _firstNameController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomInputField(
                              label: 'Nom (optionnel)',
                              hint: 'Agbo',
                              prefixIcon: Icons.person_outline,
                              controller: _lastNameController,
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildError(_error!),
                      ],
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Accepter l\'invitation',
                        icon: Icons.check_circle_outline,
                        isLoading: session.busy,
                        onPressed: session.busy ? null : _submit,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: session.busy ? null : widget.onCancel,
                        child: const Text('Plus tard',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.dangerText.withValues(alpha: 0.25)),
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
                  color: AppColors.dangerText, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
