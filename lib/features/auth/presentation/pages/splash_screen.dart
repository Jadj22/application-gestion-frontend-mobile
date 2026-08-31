import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Écran de démarrage affiché après l'icône native de l'application :
/// icône DODOME centrée, logo de l'éditeur (Blue Light Events) en bas.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cercle decoratif en haut a droite
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
            // Cercle decoratif en bas a gauche
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
            // Contenu principal
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  // Logo de l'app
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Icon(
                              Icons.inventory_2,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  // Logo de la societe
                  FadeTransition(
                    opacity: _fade,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: 32 + bottomPadding,
                      ),
                      child: Image.asset(
                        'assets/logo_company.jpg',
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Text(
                          'DODOME',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
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
}
