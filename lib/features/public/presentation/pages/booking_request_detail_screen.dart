import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/booking_request_model.dart';
import '../../data/repositories/booking_request_repository.dart';

/// Écran détail/suivi demande client via token (V2)
class BookingRequestDetailScreen extends StatefulWidget {
  final String slug;
  final String businessName;
  final String token;

  const BookingRequestDetailScreen({
    super.key,
    required this.slug,
    required this.businessName,
    required this.token,
  });

  @override
  State<BookingRequestDetailScreen> createState() =>
      _BookingRequestDetailScreenState();
}

class _BookingRequestDetailScreenState
    extends State<BookingRequestDetailScreen> {
  late final BookingRequestRepository _repository;
  BookingRequestModel? _request;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _repository = BookingRequestRepository(apiClient);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await _repository.getPublicDetail(
        slug: widget.slug,
        token: widget.token,
      );
      if (mounted) {
        setState(() {
          _request = request;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma demande'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetail,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadDetail)
              : _request == null
                  ? const Center(child: Text('Demande introuvable'))
                  : RefreshIndicator(
                      onRefresh: _loadDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header statut
                            _StatusCard(request: _request!),
                            const SizedBox(height: 16),

                            // Article
                            _ItemCard(request: _request!),
                            const SizedBox(height: 16),

                            // Périodes & quantité
                            _InfoSection(
                              title: 'Période & Quantité',
                              children: [
                                _InfoRow('Période', _request!.periodeFormatee),
                                _InfoRow('Quantité',
                                    '${_request!.quantite} ${_request!.itemUnite}'),
                                _InfoRow('Prix unitaire',
                                    _request!.itemPrixFormate),
                                _InfoRow('Total estimé',
                                    _request!.montantTotal),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Lieu & contact
                            if (_request!.lieuNom.isNotEmpty ||
                                _request!.lieuAdresse.isNotEmpty) ...[
                              _InfoSection(
                                title: 'Lieu de livraison',
                                children: [
                                  if (_request!.lieuNom.isNotEmpty)
                                    _InfoRow('Lieu', _request!.lieuNom),
                                  if (_request!.lieuAdresse.isNotEmpty)
                                    _InfoRow('Adresse', _request!.lieuAdresse),
                                  if (_request!.contactNom.isNotEmpty)
                                    _InfoRow('Contact', _request!.contactNom),
                                  if (_request!.contactTelephone.isNotEmpty)
                                    _InfoRow('Téléphone contact',
                                        _request!.contactTelephone),
                                  if (_request!.notesLivraison.isNotEmpty)
                                    _InfoRow('Notes', _request!.notesLivraison),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Message client
                            if (_request!.message.isNotEmpty) ...[
                              _InfoSection(
                                title: 'Votre message',
                                children: [
                                  _InfoRow('', _request!.message,
                                      isFullWidth: true),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Contre-proposition
                            if (_request!.aContreProposition) ...[
                              _CounterProposalCard(
                                request: _request!,
                                slug: widget.slug,
                                token: widget.token,
                                onRefreshNeeded: _loadDetail,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Actions selon statut
                            _ActionsSection(
                              request: _request!,
                              slug: widget.slug,
                              token: widget.token,
                              onRefreshNeeded: _loadDetail,
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final BookingRequestModel request;

  const _StatusCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: request.statutColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _statusIcon(request.statut),
              color: request.statutColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.statutDisplay,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: request.statutColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusDescription(request.statut),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (request.aContreProposition)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Contre-proposition',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String statut) {
    switch (statut) {
      case 'EN_ATTENTE':
        return Icons.hourglass_empty;
      case 'ACCEPTEE':
        return Icons.check_circle;
      case 'REFUSEE':
        return Icons.cancel;
      case 'EXPIREE':
        return Icons.timer_off;
      case 'ANNULEE_CLIENT':
        return Icons.close;
      case 'CONVERTIE':
        return Icons.assignment_turned_in;
      default:
        return Icons.help;
    }
  }

  String _statusDescription(String statut) {
    switch (statut) {
      case 'EN_ATTENTE':
        return 'L\'équipe examine votre demande';
      case 'ACCEPTEE':
        return 'Demande acceptée, réservation en cours';
      case 'REFUSEE':
        return 'Demande refusée par l\'équipe';
      case 'EXPIREE':
        return 'Aucune réponse dans les délais';
      case 'ANNULEE_CLIENT':
        return 'Vous avez annulé cette demande';
      case 'CONVERTIE':
        return 'Réservation confirmée';
      default:
        return '';
    }
  }
}

class _ItemCard extends StatelessWidget {
  final BookingRequestModel request;

  const _ItemCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 70,
                height: 70,
                child: request.itemPhotoUrl != null
                    ? Image.network(request.itemPhotoUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.grey[200]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.itemNom,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (request.itemReference.isNotEmpty)
                    Text('Ref: ${request.itemReference}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey)),
                  Text(
                    '${request.itemPrixFormate}/${request.itemUnite}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
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

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isFullWidth;

  const _InfoRow(this.label, this.value, {this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    if (isFullWidth) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _CounterProposalCard extends StatelessWidget {
  final BookingRequestModel request;
  final String slug;
  final String token;
  final VoidCallback onRefreshNeeded;

  const _CounterProposalCard({
    required this.request,
    required this.slug,
    required this.token,
    required this.onRefreshNeeded,
  });

  String _formatPrice(dynamic rawPrice) {
    if (rawPrice == null) return '';
    final parsed = num.tryParse(rawPrice.toString());
    if (parsed == null) return rawPrice.toString();
    return NumberFormat('#,##0', 'fr_FR').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contre = request.contreProposition ?? {};

    return Card(
      color: Colors.blue.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Contre-proposition de l\'équipe',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contre['date_debut'] != null || contre['date_fin'] != null)
              _InfoRow('Nouvelles dates',
                  '${contre['date_debut']} - ${contre['date_fin']}'),
            if (contre['quantite'] != null)
              _InfoRow('Nouvelle quantité', '${contre['quantite']}'),
            if (contre['prix'] != null)
              _InfoRow('Nouveau prix',
                  '${_formatPrice(contre['prix'])} FCFA/${request.itemUnite}'),
            if (contre['message'] != null &&
                contre['message'].toString().isNotEmpty)
              _InfoRow('Message', contre['message'].toString()),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Refuser'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _showRejectDialog(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Accepter'),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: () => _acceptCounter(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _RejectDialog(
        onConfirm: (motif) => _rejectCounter(context, motif),
      ),
    );
  }

  Future<void> _acceptCounter(BuildContext context) async {
    final repo = BookingRequestRepository(context.read<ApiClient>());
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repo.acceptCounterPublic(slug: slug, token: token);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Contre-proposition acceptée ! Réservation créée.'),
          backgroundColor: Colors.green,
        ),
      );
      onRefreshNeeded();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectCounter(BuildContext context, String motif) async {
    final repo = BookingRequestRepository(context.read<ApiClient>());
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repo.rejectCounterPublic(
          slug: slug, token: token, motifRefus: motif);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Contre-proposition refusée'),
          backgroundColor: Colors.orange,
        ),
      );
      onRefreshNeeded();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

/// Dialog personnalisé gérant la libération mémoire du controller
class _RejectDialog extends StatefulWidget {
  final Function(String motif) onConfirm;

  const _RejectDialog({required this.onConfirm});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Refuser la contre-proposition'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Motif du refus (optionnel)',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            final motif = _controller.text.trim();
            Navigator.pop(context);
            widget.onConfirm(motif);
          },
          child: const Text('Confirmer le refus'),
        ),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final BookingRequestModel request;
  final String slug;
  final String token;
  final VoidCallback onRefreshNeeded;

  const _ActionsSection({
    required this.request,
    required this.slug,
    required this.token,
    required this.onRefreshNeeded,
  });

  @override
  Widget build(BuildContext context) {
    if (request.peutAnnuler && !request.aContreProposition) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cancel_outlined, color: Colors.red),
          title: const Text('Annuler ma demande',
              style: TextStyle(color: Colors.red)),
          subtitle: const Text('Cette action est irréversible'),
          onTap: () => _showCancelDialog(context),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la demande'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette demande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = BookingRequestRepository(context.read<ApiClient>());
              final messenger = ScaffoldMessenger.of(context);

              try {
                await repo.cancelPublic(slug: slug, token: token);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Demande annulée'),
                    backgroundColor: Colors.orange,
                  ),
                );
                onRefreshNeeded();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Erreur: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erreur de chargement',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}