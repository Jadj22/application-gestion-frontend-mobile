import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../session_controller.dart';

/// Écran de succès affiché après une connexion ou une inscription réussie :
/// coche animée + message, puis redirection automatique (onboarding ou accueil).
class WelcomeScreen extends StatefulWidget {
  final String message;
  final VoidCallback onDone;

  const WelcomeScreen({
    super.key,
    required this.message,
    required this.onDone,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _redirectTimer = Timer(const Duration(milliseconds: 2200), widget.onDone);
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final displayName = user == null
        ? null
        : user.firstName.isEmpty
            ? user.email
            : user.firstName;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _controller,
                        curve: Curves.elasticOut,
                      ),
                      child: FadeTransition(
                        opacity: _controller,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  AppColors.successText.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.successText.withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 52,
                            color: AppColors.successText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h1,
                    ),
                    if (displayName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Bienvenue $displayName 👋',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Redirection...',
              style: TextStyle(fontSize: 13, color: AppColors.hint),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}