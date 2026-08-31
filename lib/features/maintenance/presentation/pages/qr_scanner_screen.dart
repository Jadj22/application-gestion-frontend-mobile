import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../data/maintenance_repository.dart';

/// Page Scanner QR Code - Sprint 6.
/// Permet de scanner un QR code pour accéder directement à un article.
///
/// La caméra est affichée dans une fenêtre flottante arrondie (et non en
/// plein écran) : le flux est contraint aux dimensions de cette fenêtre,
/// les contrôles sont posés en dessous sur un fond clair.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  /// Proportion de la fenêtre caméra occupée par la zone de détection.
  /// Sert à la fois au `scanWindow` du contrôleur et au cadre dessiné :
  /// les deux restent ainsi cohérents.
  static const double _scanRatio = 0.68;

  late final MobileScannerController _controller;
  late final AnimationController _lineController;

  bool _isScanning = true;
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lineController.dispose();
    // `dispose()` du contrôleur est asynchrone : on ne peut pas l'attendre
    // ici, mais l'appel libère bien la caméra.
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;

    // Évite de scanner plusieurs fois le même code
    if (code == _lastScannedCode) return;
    _lastScannedCode = code;

    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });

    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) {
        throw Exception('Business non sélectionné');
      }

      final repo = context.read<MaintenanceRepository>();
      final item = await repo.scanItem(businessId, code);

      if (!mounted) return;

      // Renvoie l'article à l'appelant (comportement métier existant).
      Navigator.of(context).pop({'item': item, 'qr_code': code});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Article non trouvé pour ce QR code'),
          backgroundColor: AppColors.dangerText,
          action: SnackBarAction(
            label: 'Réessayer',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _isProcessing = false;
                _isScanning = true;
                _lastScannedCode = null;
              });
            },
          ),
        ),
      );

      setState(() {
        _isProcessing = false;
        _isScanning = true;
        // Autorise un nouvel essai sur le même code.
        _lastScannedCode = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    // Fenêtre caméra verticale : ~58 % de la hauteur, bornée pour rester
    // lisible sur petits écrans comme sur tablettes.
    final windowHeight = (media.height * 0.58).clamp(320.0, 620.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        'Scanner un QR code',
                        style: AppTextStyles.h2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Placez le code dans le cadre, le scan est automatique.',
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Plafonne la hauteur sur grands écrans sans jamais
                        // déborder sur les petits.
                        final height =
                            math.min(windowHeight, constraints.maxHeight);
                        return Center(
                          child: SizedBox(
                            height: height,
                            width: double.infinity,
                            child: _CameraWindow(
                              controller: _controller,
                              lineAnimation: _lineController,
                              scanRatio: _scanRatio,
                              isProcessing: _isProcessing,
                              onDetect: _onDetect,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ControlsBar(
                  controller: _controller,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fenêtre caméra : flux contraint + cadre de scan + états
// ---------------------------------------------------------------------------

class _CameraWindow extends StatelessWidget {
  final MobileScannerController controller;
  final Animation<double> lineAnimation;
  final double scanRatio;
  final bool isProcessing;
  final void Function(BarcodeCapture) onDetect;

  const _CameraWindow({
    required this.controller,
    required this.lineAnimation,
    required this.scanRatio,
    required this.isProcessing,
    required this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // La zone de détection réelle (`scanWindow`) et le cadre dessiné
            // partagent ce même rectangle : ce que l'utilisateur voit
            // correspond à ce qui est réellement analysé.
            final side =
                math.min(constraints.maxWidth, constraints.maxHeight) *
                    scanRatio;
            final scanRect = Rect.fromCenter(
              center: Offset(
                constraints.maxWidth / 2,
                constraints.maxHeight / 2,
              ),
              width: side,
              height: side,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: onDetect,
                  scanWindow: scanRect,
                  fit: BoxFit.cover,
                  placeholderBuilder: (context, child) =>
                      const _CameraMessage.loading(),
                  errorBuilder: (context, error, child) =>
                      _CameraMessage.error(error: error),
                ),

                // Cadre de scan (coins + voile sombre autour).
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ScanFramePainter(scanRect: scanRect),
                    size: Size.infinite,
                  ),
                ),

                // Ligne de balayage : indique que le scanner est actif.
                if (!isProcessing)
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: lineAnimation,
                      builder: (context, _) {
                        final y = scanRect.top +
                            scanRect.height * lineAnimation.value;
                        return Stack(
                          children: [
                            Positioned(
                              left: scanRect.left + 10,
                              width: scanRect.width - 20,
                              top: y,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0),
                                      AppColors.primary,
                                      AppColors.primary.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                // Recherche de l'article en cours.
                if (isProcessing)
                  const ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Recherche de l\'article...',
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// États non-caméra affichés dans la fenêtre : chargement, permission, erreur.
class _CameraMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool showSpinner;

  const _CameraMessage._({
    required this.icon,
    required this.title,
    this.subtitle,
    this.showSpinner = false,
  });

  const _CameraMessage.loading()
      : this._(
          icon: Icons.photo_camera_outlined,
          title: 'Démarrage de la caméra...',
          showSpinner: true,
        );

  factory _CameraMessage.error({required MobileScannerException error}) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return _CameraMessage._(
      icon: denied ? Icons.no_photography_outlined : Icons.error_outline,
      title: denied ? 'Accès à la caméra refusé' : 'Caméra indisponible',
      subtitle: denied
          ? 'Autorisez la caméra dans les réglages de votre téléphone '
              'pour scanner un QR code.'
          : error.errorDetails?.message ??
              'Impossible de démarrer la caméra sur cet appareil.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSpinner)
                const CircularProgressIndicator(color: Colors.white)
              else
                Icon(icon, size: 44, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Voile sombre autour de la zone de scan + coins accentués.
class _ScanFramePainter extends CustomPainter {
  final Rect scanRect;

  const _ScanFramePainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = const Radius.circular(20);
    final rrect = RRect.fromRectAndRadius(scanRect, radius);

    // Assombrit tout sauf la zone de scan.
    final scrim = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(rrect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, scrim, hole),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Liseré discret sur tout le contour.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    // Coins accentués — repère net quelle que soit la luminosité.
    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final len = scanRect.width * 0.16;

    void drawCorner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(dx * len, 0), corner);
      canvas.drawLine(origin, origin.translate(0, dy * len), corner);
    }

    drawCorner(scanRect.topLeft, 1, 1);
    drawCorner(scanRect.topRight, -1, 1);
    drawCorner(scanRect.bottomLeft, 1, -1);
    drawCorner(scanRect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.scanRect != scanRect;
}

// ---------------------------------------------------------------------------
// Contrôles circulaires sous la caméra
// ---------------------------------------------------------------------------

class _ControlsBar extends StatelessWidget {
  final MobileScannerController controller;
  final VoidCallback onClose;

  const _ControlsBar({required this.controller, required this.onClose});

  @override
  Widget build(BuildContext context) {
    // Ne reconstruit que la barre de contrôles quand l'état caméra change
    // (torche, objectif) — le flux vidéo n'est pas impacté.
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final torchOn = state.torchState == TorchState.on;
        final torchAvailable = state.torchState != TorchState.unavailable;
        final canSwitch = (state.availableCameras ?? 2) > 1;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleButton(
              icon: torchOn ? Icons.flash_on : Icons.flash_off,
              label: 'Flash',
              active: torchOn,
              onPressed: torchAvailable ? controller.toggleTorch : null,
            ),
            const SizedBox(width: 20),
            _CircleButton(
              icon: Icons.cameraswitch_outlined,
              label: 'Objectif',
              onPressed: canSwitch ? controller.switchCamera : null,
            ),
            const SizedBox(width: 20),
            _CircleButton(
              icon: Icons.close,
              label: 'Fermer',
              onPressed: onClose,
            ),
          ],
        );
      },
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  const _CircleButton({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final background = active ? AppColors.primary : AppColors.surface;
    final foreground = disabled
        ? AppColors.dashOutline
        : active
            ? Colors.white
            : AppColors.dashPrimary;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: background,
          shape: CircleBorder(
            side: BorderSide(
              color: active ? AppColors.primary : AppColors.dashOutlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, size: 22, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
