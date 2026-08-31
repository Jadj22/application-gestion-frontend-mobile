import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget chronomètre pour les étapes de tâche - Sprint 6.
/// Affiche un timer avec start/pause/stop pour mesurer le temps passé.
class StepTimerWidget extends StatefulWidget {
  /// Durée estimée en secondes (pour comparaison)
  final int? estimatedSeconds;

  /// Durée déjà écoulée (si reprise)
  final int initialSeconds;

  /// Callback quand le timer démarre
  final VoidCallback? onStart;

  /// Callback quand le timer est mis en pause
  final VoidCallback? onPause;

  /// Callback quand le timer s'arrête avec la durée finale
  final void Function(int seconds)? onStop;

  /// Mode compact (pour les listes)
  final bool compact;

  const StepTimerWidget({
    super.key,
    this.estimatedSeconds,
    this.initialSeconds = 0,
    this.onStart,
    this.onPause,
    this.onStop,
    this.compact = false,
  });

  @override
  State<StepTimerWidget> createState() => _StepTimerWidgetState();
}

class _StepTimerWidgetState extends State<StepTimerWidget> {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _seconds++;
      });
    });

    widget.onStart?.call();
  }

  void _pause() {
    if (!_isRunning) return;

    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    widget.onPause?.call();
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    widget.onStop?.call(_seconds);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _seconds = 0;
    });
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getProgressColor() {
    if (widget.estimatedSeconds == null || widget.estimatedSeconds == 0) {
      return AppColors.primary;
    }

    final ratio = _seconds / widget.estimatedSeconds!;
    if (ratio <= 0.8) return Colors.green;
    if (ratio <= 1.0) return Colors.orange;
    return Colors.red;
  }

  double _getProgressValue() {
    if (widget.estimatedSeconds == null || widget.estimatedSeconds == 0) {
      return 0;
    }
    return (_seconds / widget.estimatedSeconds!).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildCompact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isRunning
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRunning)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                _formatTime(_seconds),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: _isRunning ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!_isRunning && _seconds == 0)
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _start,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: AppColors.primary,
          )
        else if (_isRunning)
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: _pause,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.orange,
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _start,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppColors.primary,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _stop,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.red,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFull() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Timer display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isRunning)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                Text(
                  _formatTime(_seconds),
                  style: const TextStyle(
                    fontSize: 48,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Progress bar (si estimation disponible)
            if (widget.estimatedSeconds != null &&
                widget.estimatedSeconds! > 0) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _getProgressValue(),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(_getProgressColor()),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Temps écoulé',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Estimé: ${_formatTime(widget.estimatedSeconds!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRunning && _seconds == 0)
                  // Start button
                  ElevatedButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Démarrer'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                  )
                else if (_isRunning)
                  // Pause button
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pause,
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _stop,
                        icon: const Icon(Icons.stop),
                        label: const Text('Terminer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  )
                else
                  // Paused state
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Reprendre'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _stop,
                        icon: const Icon(Icons.check),
                        label: const Text('Terminer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget affichant la comparaison temps réel vs estimé.
class TimerComparisonWidget extends StatelessWidget {
  final int actualSeconds;
  final int? estimatedSeconds;

  const TimerComparisonWidget({
    super.key,
    required this.actualSeconds,
    this.estimatedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    if (estimatedSeconds == null || estimatedSeconds == 0) {
      return Text(
        _formatTime(actualSeconds),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    }

    final diff = actualSeconds - estimatedSeconds!;
    final isOver = diff > 0;
    final color = isOver ? Colors.red : Colors.green;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(actualSeconds),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${isOver ? '+' : '-'}${_formatTime(diff.abs())}',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    }
    if (minutes > 0) {
      return '${minutes}m${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }
}
