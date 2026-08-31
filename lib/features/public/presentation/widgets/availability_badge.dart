import 'package:flutter/material.dart';

/// Badge de disponibilité pour le catalogue public
class AvailabilityBadge extends StatelessWidget {
  final int? disponible;
  final bool? peutReserver;
  final bool showLabel;

  const AvailabilityBadge({
    super.key,
    this.disponible,
    this.peutReserver,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (peutReserver == false || disponible == 0) {
      return _Badge(
        label: showLabel ? 'Indisponible' : '',
        color: Colors.red,
        icon: Icons.block,
        showLabel: showLabel,
      );
    }

    if (disponible == null) {
      return _Badge(
        label: showLabel ? 'Dispo ?' : '',
        color: Colors.grey,
        icon: Icons.help_outline,
        showLabel: showLabel,
      );
    }

    if (disponible! <= 3) {
      return _Badge(
        label: showLabel ? 'Il reste $disponible' : '',
        color: Colors.orange,
        icon: Icons.warning_amber_rounded,
        showLabel: showLabel,
      );
    }

    return _Badge(
      label: showLabel ? 'Disponible' : '',
      color: Colors.green,
      icon: Icons.check_circle,
      showLabel: showLabel,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool showLabel;

  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (!showLabel && label.isEmpty) {
      return Icon(icon, color: color, size: 18);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          if (showLabel && label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}