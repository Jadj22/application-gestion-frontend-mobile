import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/auth_repository.dart';
import '../session_controller.dart';

/// Saisie d'un code d'invitation (Sprint 11) : l'utilisateur entre
/// le code recu par email (DODO-XXXXXX) pour rejoindre un business.
///
/// Flux : saisie du code -> validation -> apercu -> acceptation.
class EnterInvitationCodePage extends StatefulWidget {
  const EnterInvitationCodePage({super.key});

  @override
  State<EnterInvitationCodePage> createState() =>
      _EnterInvitationCodePageState();
}

class _EnterInvitationCodePageState extends State<EnterInvitationCodePage> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  String? _error;
  InvitationValidation? _validation;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    // Efface l'erreur et la validation quand l'utilisateur modifie le code
    if (_error != null || _validation != null) {
      setState(() {
        _error = null;
        _validation = null;
      });
    }
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Veuillez entrer un code d\'invitation.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = context.read<AuthRepository>();
      final validation = await repository.validateCode(code);
      if (mounted) {
        setState(() {
          _validation = validation;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } on SocketException catch (e) {
      debugPrint('SocketException: $e');
      if (mounted) {
        setState(() {
          _error = 'Serveur injoignable. Verifiez que le backend est demarre.';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Validation error: $e');
      if (mounted) {
        setState(() {
          _error = 'Erreur: ${e.runtimeType} - $e';
          _loading = false;
        });
      }
    }
  }

  void _acceptInvitation() {
    if (_validation == null) return;
    final code = _codeController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AcceptInvitationByCodePage(
          code: code,
          validation: _validation!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icone
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
                  child: const Icon(Icons.mail_outline,
                      size: 36, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),

              // Titre
              const Text(
                'Vous avez recu une invitation ?',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez le code recu par email pour rejoindre une equipe.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Champ de saisie du code
              _CodeInputField(
                controller: _codeController,
                focusNode: _focusNode,
                enabled: !_loading,
                onSubmitted: (_) => _validateCode(),
              ),

              // Erreur
              if (_error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: _error!),
              ],

              // Apercu de l'invitation
              if (_validation != null) ...[
                const SizedBox(height: 24),
                _InvitationPreviewCard(validation: _validation!),
              ],

              const SizedBox(height: 24),

              // Bouton d'action
              if (_validation == null)
                PrimaryButton(
                  label: 'Verifier le code',
                  icon: Icons.search,
                  isLoading: _loading,
                  onPressed: _loading ? null : _validateCode,
                )
              else
                PrimaryButton(
                  label: 'Accepter l\'invitation',
                  icon: Icons.check_circle_outline,
                  onPressed: _acceptInvitation,
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Champ de saisie stylise pour le code d'invitation.
class _CodeInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  const _CodeInputField({
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'DODO-XXXXXX',
          hintStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
          LengthLimitingTextInputFormatter(12), // DODO-XXXXXX = 11 chars + 1
          _CodeFormatter(),
        ],
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// Formatter pour le code d'invitation : insere automatiquement le tiret.
class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Retire tout sauf alphanumerique
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.isEmpty) return newValue.copyWith(text: '');

    // Format: DODO-XXXXXX
    String formatted;
    if (raw.length > 4) {
      formatted = '${raw.substring(0, 4)}-${raw.substring(4, raw.length.clamp(4, 10))}';
    } else {
      formatted = raw;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Carte d'apercu de l'invitation validee.
class _InvitationPreviewCard extends StatelessWidget {
  final InvitationValidation validation;

  const _InvitationPreviewCard({required this.validation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.successText.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.successText,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Code valide',
                style: AppTextStyles.fieldLabel.copyWith(
                  color: AppColors.successText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Vous etes invite(e) a rejoindre :',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            validation.businessNom,
            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
          ),
          if (validation.role != null) ...[
            const SizedBox(height: 4),
            Text(
              'Role : ${validation.role}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (validation.inviteur != null) ...[
            const SizedBox(height: 4),
            Text(
              'Invite par : ${validation.inviteur}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Pour : ${validation.email}',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

/// Page d'acceptation apres validation du code.
/// L'utilisateur doit creer son mot de passe pour finaliser l'inscription.
class _AcceptInvitationByCodePage extends StatefulWidget {
  final String code;
  final InvitationValidation validation;

  const _AcceptInvitationByCodePage({
    required this.code,
    required this.validation,
  });

  @override
  State<_AcceptInvitationByCodePage> createState() =>
      _AcceptInvitationByCodePageState();
}

class _AcceptInvitationByCodePageState
    extends State<_AcceptInvitationByCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _telephoneController = TextEditingController();

  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final session = context.read<SessionController>();
    try {
      await session.acceptInvitation(
        code: widget.code,
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        telephone: _telephoneController.text.trim(),
      );
      if (mounted) {
        // Retourne a la racine apres l'acceptation
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icone
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
                    child: const Icon(Icons.person_add,
                        size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),

                // Titre
                Text(
                  'Rejoindre ${widget.validation.businessNom}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1,
                ),
                const SizedBox(height: 8),
                Text(
                  'Creez votre compte pour accepter l\'invitation.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.validation.email,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Champs du formulaire
                _InputField(
                  label: 'Mot de passe *',
                  hint: 'Au moins 8 caracteres',
                  icon: Icons.lock_outline,
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
                    final v = value ?? '';
                    if (v.length < 8) return 'Au moins 8 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _InputField(
                  label: 'Confirmer le mot de passe *',
                  hint: 'Repetez le mot de passe',
                  icon: Icons.lock_outline,
                  controller: _confirmController,
                  isPassword: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value != _passwordController.text
                      ? 'Les mots de passe ne correspondent pas'
                      : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        label: 'Prenom (optionnel)',
                        hint: 'Kossi',
                        icon: Icons.person_outline,
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InputField(
                        label: 'Nom (optionnel)',
                        hint: 'Agbo',
                        icon: Icons.person_outline,
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _InputField(
                  label: 'Telephone (optionnel)',
                  hint: '+228 90 00 00 00',
                  icon: Icons.phone_outlined,
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _error!),
                ],

                const SizedBox(height: 28),

                PrimaryButton(
                  label: 'Accepter l\'invitation',
                  icon: Icons.check_circle_outline,
                  isLoading: session.busy,
                  onPressed: session.busy ? null : _submit,
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ de saisie stylise.
class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _InputField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
            prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.dangerText),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.dangerText, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
