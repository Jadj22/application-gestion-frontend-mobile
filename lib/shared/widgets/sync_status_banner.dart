import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/offline/connectivity/connectivity_service.dart';
import '../../core/offline/sync/sync_engine.dart';
import '../../core/offline/sync/sync_operation.dart';
import '../../core/theme/app_colors.dart';

/// Apparence de l'état de synchronisation : couleur, icône, texte.
class _SyncLook {
  final Color color;
  final IconData icon;
  final String label;
  final String? detail;

  const _SyncLook(this.color, this.icon, this.label, [this.detail]);
}

_SyncLook _lookFor(SyncEngine engine, ConnectivityService connectivity) {
  final pending = engine.pendingCount;
  final plural = pending > 1 ? 's' : '';

  if (engine.state == SyncState.syncing) {
    return _SyncLook(
      const Color(0xFFEA8C00),
      Icons.sync,
      'Synchronisation…',
      pending > 0 ? '$pending opération$plural en cours d\'envoi' : null,
    );
  }

  if (engine.failedCount > 0) {
    final failed = engine.failedCount;
    return _SyncLook(
      const Color(0xFFD93025),
      Icons.error_outline,
      'Erreur de synchronisation',
      '$failed opération${failed > 1 ? 's' : ''} à vérifier',
    );
  }

  if (connectivity.isOffline) {
    return _SyncLook(
      const Color(0xFF8A8F98),
      Icons.cloud_off,
      'Hors ligne',
      pending > 0
          ? '$pending modification$plural en attente de synchronisation'
          : 'Vos données restent disponibles',
    );
  }

  if (pending > 0) {
    return _SyncLook(
      const Color(0xFFEA8C00),
      Icons.cloud_upload_outlined,
      'En attente',
      '$pending modification$plural à envoyer',
    );
  }

  return const _SyncLook(
    Color(0xFF1E8E3E),
    Icons.cloud_done_outlined,
    'Synchronisé',
    'Toutes les données sont synchronisées',
  );
}

/// Bandeau d'état affiché en haut des écrans principaux.
///
/// Il n'interrompt jamais le travail en cours : hors ligne, l'application reste
/// entièrement utilisable, et le bandeau se contente de dire ce qui attend
/// d'être envoyé. Il disparaît quand tout est synchronisé, pour ne pas occuper
/// d'espace en régime normal.
class SyncStatusBanner extends StatelessWidget {
  /// Afficher aussi l'état « tout est synchronisé » (utile juste après un
  /// retour en ligne, pour confirmer que le travail est bien parti).
  final bool showWhenIdle;

  const SyncStatusBanner({super.key, this.showWhenIdle = false});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SyncEngine>();
    final connectivity = context.watch<ConnectivityService>();

    // Tant que l'etat reseau n'a pas ete mesure, ne rien affirmer : afficher
    // « Hors ligne » une fraction de seconde au demarrage serait faux.
    if (!connectivity.isDetermined && engine.pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final isIdle = engine.state == SyncState.idle &&
        engine.pendingCount == 0 &&
        engine.failedCount == 0 &&
        connectivity.isOnline;
    if (isIdle && !showWhenIdle) return const SizedBox.shrink();

    final look = _lookFor(engine, connectivity);
    final actionable = engine.failedCount > 0 ||
        (engine.pendingCount > 0 && connectivity.isOnline);

    return Material(
      color: look.color.withValues(alpha: 0.10),
      child: InkWell(
        onTap: actionable
            ? () => _showPendingSheet(context, engine)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _StatusIcon(look: look, spinning: engine.state == SyncState.syncing),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      look.label,
                      style: TextStyle(
                        color: look.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (look.detail != null)
                      Text(
                        look.detail!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (actionable)
                Icon(Icons.chevron_right, size: 20, color: look.color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPendingSheet(BuildContext context, SyncEngine engine) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SyncPendingSheet(engine: engine),
    );
  }
}

class _StatusIcon extends StatefulWidget {
  final _SyncLook look;
  final bool spinning;

  const _StatusIcon({required this.look, required this.spinning});

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(_StatusIcon old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.look.icon, size: 18, color: widget.look.color);
    if (!widget.spinning) return icon;
    return RotationTransition(turns: _controller, child: icon);
  }
}

/// Détail de ce qui reste à synchroniser, avec l'action « Réessayer ».
///
/// Répond à la question que se pose l'utilisateur hors ligne : « qu'est-ce qui
/// n'est pas encore parti ? ». Sans cette vue, le compteur du bandeau ne serait
/// qu'un chiffre opaque.
class SyncPendingSheet extends StatefulWidget {
  final SyncEngine engine;

  const SyncPendingSheet({super.key, required this.engine});

  @override
  State<SyncPendingSheet> createState() => _SyncPendingSheetState();
}

class _SyncPendingSheetState extends State<SyncPendingSheet> {
  late Future<List<_PendingRow>> _rows = _load();
  bool _retrying = false;

  Future<List<_PendingRow>> _load() async {
    final operations = await widget.engine.outstandingOperations();
    return operations.map(_PendingRow.from).toList();
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await widget.engine.retryFailed();
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _rows = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En attente de synchronisation',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ces modifications sont enregistrées sur votre téléphone. '
              'Elles partiront automatiquement dès le retour du réseau.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<List<_PendingRow>>(
                future: _rows,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final rows = snapshot.data!;
                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Toutes les données sont synchronisées.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) => rows[index].build(context),
                  );
                },
              ),
            ),
            if (widget.engine.failedCount > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(_retrying ? 'Nouvelle tentative…' : 'Réessayer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingRow {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool failed;

  const _PendingRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.failed,
  });

  factory _PendingRow.from(SyncOperation operation) {
    final label = _entityLabel(operation.entityType);
    final verb = switch (operation.type) {
      SyncOperationType.create => 'Création',
      SyncOperationType.update => 'Modification',
      SyncOperationType.delete => 'Suppression',
      SyncOperationType.upload => 'Envoi de photo',
      SyncOperationType.action => 'Action',
    };
    final failed = operation.status == SyncOperationStatus.failed;
    final error = operation.lastError;
    final retry = operation.retryCount;
    return _PendingRow(
      title: '$verb — $label',
      subtitle: failed && error != null
          ? error
          : retry > 0
              ? 'Nouvelle tentative programmée (essai ${retry + 1})'
              : "En attente d'envoi",
      icon: failed ? Icons.error_outline : Icons.schedule,
      failed: failed,
    );
  }

  static String _entityLabel(String type) => switch (type) {
        'item' => 'article',
        'category' => 'catégorie',
        'maintenance_task' => 'tâche d\'entretien',
        'procedure' => 'procédure',
        'stock_movement' => 'mouvement de stock',
        'reservation' => 'réservation',
        'recurring_task' => 'tâche récurrente',
        'reminder' => 'rappel',
        'task_comment' => 'commentaire',
        _ => type,
      };

  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          icon,
          color: failed ? const Color(0xFFD93025) : AppColors.textSecondary,
        ),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
