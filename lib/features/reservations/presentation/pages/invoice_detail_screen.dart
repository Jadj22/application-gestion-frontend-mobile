import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/offline/offline_repository.dart';
import '../../../public/data/models/invoice_model.dart';
import '../../data/repositories/invoice_repository.dart';

/// Détail facture pour l'équipe (V4)
class InvoiceDetailScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String invoiceId;
  final InvoiceRepository? repository;

  const InvoiceDetailScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.invoiceId,
    this.repository,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late final InvoiceRepository _repository;
  InvoiceModel? _invoice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        InvoiceRepository(
          context.read<ApiClient>(),
          context.read<OfflineRepository>(),
        );
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _invoice = await _repository.getTeamDetail(
        businessId: widget.businessId,
        invoiceId: widget.invoiceId,
      );
    } catch (e) {
      _error = 'Erreur: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markSent() async {
    if (_invoice == null) return;
    try {
      await _repository.markSent(
        businessId: widget.businessId,
        invoiceId: widget.invoiceId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Facture marquée comme envoyée'),
          backgroundColor: Colors.green,
        ),
      );
      _loadDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markPaid() async {
    if (_invoice == null) return;
    try {
      await _repository.markPaid(
        businessId: widget.businessId,
        invoiceId: widget.invoiceId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Facture marquée comme payée'),
          backgroundColor: Colors.green,
        ),
      );
      _loadDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;
    try {
      await _repository.downloadPdf(
        businessId: widget.businessId,
        invoiceId: widget.invoiceId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF téléchargé'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la facture'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette facture ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // TODO: Ajouter endpoint annulation facture côté backend
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fonctionnalité non disponible'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail facture'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_loading && _invoice != null) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _downloadPdf,
              tooltip: 'Télécharger PDF',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'sent') _markSent();
                if (value == 'paid') _markPaid();
                if (value == 'cancel') _showCancelDialog();
              },
              itemBuilder: (context) => [
                if (_invoice!.envoyeeLe == null && _invoice!.statut != 'PAYEE')
                  const PopupMenuItem(
                    value: 'sent',
                    child: Text('Marquer envoyée'),
                  ),
                if (_invoice!.statut != 'PAYEE')
                  const PopupMenuItem(
                    value: 'paid',
                    child: Text('Marquer payée'),
                  ),
                if (_invoice!.statut != 'ANNULEE')
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Annuler'),
                  ),
              ],
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadDetail)
              : _invoice == null
                  ? const Center(child: Text('Facture introuvable'))
                  : RefreshIndicator(
                      onRefresh: _loadDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InvoiceHeader(invoice: _invoice!),
                            const SizedBox(height: 16),
                            _InfoSection(
                              title: 'Client',
                              children: [
                                _InfoRow('Nom', _invoice!.clientNom),
                                if (_invoice!.clientEmail.isNotEmpty)
                                  _InfoRow('Email', _invoice!.clientEmail),
                                if (_invoice!.clientTelephone.isNotEmpty)
                                  _InfoRow(
                                    'Téléphone',
                                    _invoice!.clientTelephone,
                                  ),
                                if (_invoice!.clientAdresse.isNotEmpty)
                                  _InfoRow('Adresse', _invoice!.clientAdresse),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoSection(
                              title: 'Réservation',
                              children: [
                                _InfoRow('Article', _invoice!.itemNom),
                                _InfoRow('Type', _invoice!.typeDisplay),
                                _InfoRow(
                                  'Réservation ID',
                                  _formatId(_invoice!.reservationId),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _LinesTable(lines: _invoice!.lignes),
                            const SizedBox(height: 16),
                            _TotalsCard(invoice: _invoice!),
                            const SizedBox(height: 16),
                            _ActionsBar(
                              invoice: _invoice!,
                              onMarkSent: _markSent,
                              onMarkPaid: _markPaid,
                              onDownloadPdf: _downloadPdf,
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
    );
  }

  String _formatId(String id) {
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }
}

class _InvoiceHeader extends StatelessWidget {
  final InvoiceModel invoice;

  const _InvoiceHeader({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: invoice.statutColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: invoice.statutColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: invoice.statutColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    invoice.statutDisplay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      invoice.numero,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      invoice.typeDisplay,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _InfoRow(
              'Date émission',
              DateFormat('dd/MM/yyyy HH:mm').format(invoice.genereeLe),
            ),
            if (invoice.envoyeeLe != null)
              _InfoRow(
                'Envoyée le',
                DateFormat('dd/MM/yyyy HH:mm').format(invoice.envoyeeLe!),
              ),
            if (invoice.payeeLe != null)
              _InfoRow(
                'Payée le',
                DateFormat('dd/MM/yyyy HH:mm').format(invoice.payeeLe!),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  final List<InvoiceLineModel> lines;

  const _LinesTable({required this.lines});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Qté',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Prix unit.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          ...lines.map(
            (line) => Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      line.description,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${line.quantite}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      line.prixUnitaireFormate,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      line.totalFormate,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

class _TotalsCard extends StatelessWidget {
  final InvoiceModel invoice;

  const _TotalsCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.primaryColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TotalRow('Sous-total', invoice.sousTotalFormate),
            if (invoice.tvaTaux > 0)
              _TotalRow(
                'TVA (${invoice.tvaTaux.toStringAsFixed(0)}%)',
                invoice.tvaMontantFormate,
              ),
            const Divider(),
            _TotalRow('Total TTC', invoice.montantTotalFormate, isTotal: true),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _TotalRow(this.label, this.value, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? primaryColor : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
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
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionsBar extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onMarkSent;
  final VoidCallback onMarkPaid;
  final VoidCallback onDownloadPdf;

  const _ActionsBar({
    required this.invoice,
    required this.onMarkSent,
    required this.onMarkPaid,
    required this.onDownloadPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF'),
          onPressed: onDownloadPdf,
        ),
        if (invoice.envoyeeLe == null && invoice.statut != 'PAYEE')
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Marquer envoyée'),
            onPressed: onMarkSent,
          ),
        if (invoice.statut != 'PAYEE')
          FilledButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Marquer payée'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: onMarkPaid,
          ),
      ],
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
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
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