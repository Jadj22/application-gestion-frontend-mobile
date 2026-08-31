import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../../../core/offline/offline_repository.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/google_sign_in_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../session_controller.dart';
import 'enter_invitation_code_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Future<void> _openEmailLoginSheet() async {
    final session = context.read<SessionController>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: AppColors.background,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      builder: (sheetContext) => ChangeNotifierProvider.value(
        value: session,
        child: const _EmailLoginSheet(),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    final session = context.read<SessionController>();
    try {
      await session.loginWithGoogle();
    } on OfflineUnsupportedException catch (e) {
      // Google exige le reseau : on l'explique au lieu d'un echec opaque.
      _showError(e.message);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      if (e is GoogleSignInException &&
          (e.code == GoogleSignInExceptionCode.canceled ||
              e.code == GoogleSignInExceptionCode.interrupted)) {
        return;
      }
      _showError('Connexion Google impossible : $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.dangerText,
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
          // Ambiance Stitch : halos diffus primary / navy.
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
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DODOME', style: AppTextStyles.wordmark),
                  const Spacer(),
                  Text(
                    'Gérez votre stock\nsans friction',
                    style: AppTextStyles.display,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'L\'élégance et la précision au service de votre inventaire B2B.',
                    style: AppTextStyles.body.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: AppDecorations.glassPanel(),
                    child: PrimaryButton(
                      label: 'Se connecter avec email',
                      variant: PrimaryButtonVariant.inverse,
                      isLoading: false,
                      onPressed: session.busy || session.googleBusy
                          ? null
                          : _openEmailLoginSheet,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _OrDivider(),
                  const SizedBox(height: 24),
                  GoogleSignInButton(
                    onPressed: session.busy || session.googleBusy
                        ? null
                        : _signInWithGoogle,
                    isLoading: session.googleBusy,
                  ),
                  const Spacer(),
                  // Bouton invitation par code (Sprint 11)
                  Center(
                    child: TextButton.icon(
                      onPressed: session.busy || session.googleBusy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EnterInvitationCodePage(),
                                ),
                              ),
                      icon: const Icon(
                        Icons.mail_outline,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      label: Text(
                        'Vous avez recu une invitation ?',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: session.busy || session.googleBusy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              ),
                      child: Text(
                        'Creer un compte',
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

/// Bottom sheet contenant le vrai formulaire email / mot de passe.
/// Ouvert uniquement quand l'utilisateur choisit "Se connecter avec email".
class _EmailLoginSheet extends StatefulWidget {
  const _EmailLoginSheet();

  @override
  State<_EmailLoginSheet> createState() => _EmailLoginSheetState();
}

class _EmailLoginSheetState extends State<_EmailLoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Retarde l'autofocus pour laisser l'animation du sheet ( ~300ms ) se terminer
    // Sinon clavier + sheet s'animent en même temps -> jank sur Android low-end
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _emailFocus.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final session = context.read<SessionController>();
    try {
      await session.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on OfflineUnsupportedException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ne rebuild que le bouton, pas tout le Form à chaque notifyListeners
    final isBusy = context.select<SessionController, bool>((s) => s.busy);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Petite poignée visuelle, standard pour un bottom sheet.
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
                  'Connexion',
                  style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Entrez vos identifiants pour continuer.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                CustomInputField(
                  label: 'Adresse email',
                  hint: 'vous@exemple.com',
                  prefixIcon: Icons.mail_outline,
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofocus: false,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
                  label: 'Mot de passe',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  isPassword: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Le mot de passe est requis' : null,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _error!),
                ],

                const SizedBox(height: 24),

                PrimaryButton(
                  label: 'Connexion',
                  isLoading: isBusy,
                  onPressed: isBusy ? null : _submit,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
