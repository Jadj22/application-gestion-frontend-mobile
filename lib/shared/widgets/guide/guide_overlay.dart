import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Une étape du guide de démarrage — pointe vers un widget réel de l'écran
/// (via [GlobalKey]) avec un titre et une description.
class GuideStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final double borderRadius;

  const GuideStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.borderRadius = 16,
  });
}

/// Lance un guide de démarrage interactif : assombrit l'écran et met en
/// surbrillance, étape par étape, les vrais widgets de l'interface (pas une
/// maquette statique) désignés par [steps].
class GuideOverlayController {
  const GuideOverlayController._();

  static Future<void> start(BuildContext context, List<GuideStep> steps) {
    final overlayState = Overlay.of(context);
    final completer = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GuideOverlay(
        steps: steps,
        onFinished: () {
          entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    overlayState.insert(entry);
    return completer.future;
  }
}

class _GuideOverlay extends StatefulWidget {
  final List<GuideStep> steps;
  final VoidCallback onFinished;

  const _GuideOverlay({required this.steps, required this.onFinished});

  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay> {
  int _index = 0;
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(0));
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= widget.steps.length) {
      widget.onFinished();
      return;
    }
    final step = widget.steps[index];
    final ctx = step.targetKey.currentContext;
    if (ctx == null) {
      // Widget introuvable (onglet pas encore construit...) : on saute.
      _goTo(index + 1);
      return;
    }
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      alignment: 0.5,
    );
    if (!mounted) return;
    final freshCtx = step.targetKey.currentContext;
    final box = freshCtx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      _goTo(index + 1);
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    setState(() {
      _index = index;
      _rect = topLeft & box.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    if (rect == null) return const SizedBox.shrink();
    final step = widget.steps[_index];
    final screen = MediaQuery.sizeOf(context);
    final padded = rect.inflate(8);
    final showBelow = screen.height - padded.bottom > 200;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {},
            child: CustomPaint(
              painter: _SpotlightPainter(rect: padded, radius: step.borderRadius),
            ),
          ),
        ),
        Positioned(
          left: padded.left,
          top: padded.top,
          width: padded.width,
          height: padded.height,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(step.borderRadius),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: showBelow ? padded.bottom + 16 : null,
          bottom: showBelow ? null : screen.height - padded.top + 16,
          child: _GuideCard(
            step: step,
            index: _index,
            total: widget.steps.length,
            onSkip: widget.onFinished,
            onNext: () => _goTo(_index + 1),
          ),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect rect;
  final double radius;

  _SpotlightPainter({required this.rect, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final combined = Path.combine(PathOperation.difference, scrim, hole);
    canvas.drawPath(combined, Paint()..color = Colors.black.withValues(alpha: 0.72));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.radius != radius;
}

class _GuideCard extends StatelessWidget {
  final GuideStep step;
  final int index;
  final int total;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _GuideCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Container(
                    width: i == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == index
                          ? AppColors.primary
                          : AppColors.dashOutlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
                const Spacer(),
                Text('${index + 1}/$total', style: AppTextStyles.fieldLabel),
              ],
            ),
            const SizedBox(height: 14),
            Text(step.title, style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text(step.description, style: AppTextStyles.body),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(onPressed: onSkip, child: const Text('Passer')),
                const Spacer(),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isLast ? 'Terminer' : 'Suivant'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
