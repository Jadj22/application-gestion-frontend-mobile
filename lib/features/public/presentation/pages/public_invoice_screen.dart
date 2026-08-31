import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/invoice_model.dart';
import '../../data/repositories/public_invoice_repository.dart';

/// Écran détail facture public (V4) — client externe via reservation_id
class PublicInvoiceScreen extends StatefulWidget {
  final String slug;
  final String businessName;
  final String reservationId;

  const PublicInvoiceScreen({
    super.key,
    required this.slug,
    required this.businessName,
    required this.reservationId,
  });

  @override
  State<PublicInvoiceScreen> createState() => _PublicInvoiceScreenState();
}

class _PublicInvoiceScreenState extends State<PublicInvoiceScreen> {
  late final PublicInvoiceRepository _repository;
  InvoiceModel? _invoice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _repository = PublicInvoiceRepository(apiClient);
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _invoice = await _repository.getPublicInvoice(
        slug: widget.slug,
        reservationId: widget.reservationId,
      );
    } catch (e) {
      _error = 'Erreur: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await _repository.downloadPdf(
        slug: widget.slug,
        reservationId: widget.reservationId,
      );
      // TODO: Ouvrir le PDF (flutter_pdfview, open_file, etc.)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF téléchargé'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facture'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_loading && _invoice != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _downloadPdf,
              tooltip: 'Télécharger PDF',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadInvoice)
              : _invoice == null
                  ? const Center(child: Text('Facture introuvable'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header facture
                          _InvoiceHeader(invoice: _invoice!),
                          const SizedBox(height: 16),

                          // Infos client
                          _InfoSection(
                            title: 'Client',
                            children: [
                              _InfoRow('Nom', _invoice!.clientNom),
                              if (_invoice!.clientEmail.isNotEmpty)
                                _InfoRow('Email', _invoice!.clientEmail),
                              if (_invoice!.clientTelephone.isNotEmpty)
                                _InfoRow('Téléphone', _invoice!.clientTelephone),
                              if (_invoice!.clientAdresse.isNotEmpty)
                                _InfoRow('Adresse', _invoice!.clientAdresse),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Article / Prestations
                          _InfoSection(
                            title: 'Détail',
                            children: [
                              _InfoRow('Article', _invoice!.itemNom),
                              _InfoRow('Type facture', _invoice!.typeDisplay),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Lignes
                          _LinesTable(lines: _invoice!.lignes),
                          const SizedBox(height: 16),

                          // Totaux
                          _TotalsCard(invoice: _invoice!),
                          const SizedBox(height: 24),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.download),
                                  label: const Text('Télécharger PDF'),
                                  onPressed: _downloadPdf,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.share),
                                  label: const Text('Partager'),
                                  onPressed: () {
                                    // TODO: Share
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: invoice.statutColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    invoice.statutDisplay,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      invoice.numero,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      invoice.typeDisplay,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _InfoRow('Date d\'émission', DateFormat('dd/MM/yyyy HH:mm').format(invoice.genereeLe)),
            if (invoice.envoyeeLe != null)
              _InfoRow('Envoyée le', DateFormat('dd/MM/yyyy HH:mm').format(invoice.envoyeeLe!)),
            if (invoice.payeeLe != null)
              _InfoRow('Payée le', DateFormat('dd/MM/yyyy HH:mm').format(invoice.payeeLe!)),
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
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Qté', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Prix unit.', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Lignes
          ...lines.map((line) => Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(line.description, style: theme.textTheme.bodyMedium)),
                    Expanded(flex: 1, child: Text('${line.quantite}', textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text(line.prixUnitaireFormate, textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text(line.totalFormate, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              )),
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
            if (invoice.tvaTaux > 0) ...[
              _TotalRow('TVA (${invoice.tvaTaux.toStringAsFixed(0)}%)', invoice.tvaMontantFormate),
            ],
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
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Theme.of(context).primaryColor : null,
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
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
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
            Text('Erreur de chargement', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
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