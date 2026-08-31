import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/offline/offline_repository.dart';
import '../../../public/data/models/invoice_model.dart';
import '../../data/repositories/invoice_repository.dart';
import 'invoice_detail_screen.dart';
import 'invoice_create_screen.dart';

/// Liste des factures pour l'équipe (V4)
class InvoiceListScreen extends StatefulWidget {
  final String businessId;
  final String businessName;

  const InvoiceListScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  late final InvoiceRepository _repository;
  late final OfflineRepository _offline;

  List<InvoiceModel> _invoices = [];
  bool _loading = true;
  String? _error;
  String? _filterStatut;
  String? _filterType;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _offline = context.read<OfflineRepository>();
    _repository = InvoiceRepository(apiClient, _offline);
    _loadInvoices();
  }

  Future<void> _loadInvoices({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _invoices = [];
      });
    }
    setState(() => _loading = true);
    try {
      final result = await _repository.getTeamList(
        businessId: widget.businessId,
        statut: _filterStatut,
        type: _filterType,
        page: _page,
      );
      setState(() {
        _invoices.addAll(result.results);
        _hasMore = result.next != null;
        _page++;
      });
    } catch (e) {
      _error = 'Erreur: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Factures - ${widget.businessName}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                if (value == 'clear') {
                  _filterStatut = null;
                  _filterType = null;
                } else if (value.startsWith('statut:')) {
                  _filterStatut = value.split(':')[1];
                } else if (value.startsWith('type:')) {
                  _filterType = value.split(':')[1];
                }
                _loadInvoices(refresh: true);
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Effacer les filtres')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'statut:PROFORMA', child: Text('Proforma')),
              const PopupMenuItem(value: 'statut:DEFINITIVE', child: Text('Définitive')),
              const PopupMenuItem(value: 'statut:PAYEE', child: Text('Payée')),
              const PopupMenuItem(value: 'statut:ANNULEE', child: Text('Annulée')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'type:PROFORMA', child: Text('Type: Proforma')),
              const PopupMenuItem(value: 'type:DEFINITIVE', child: Text('Type: Définitive')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToCreate(),
          ),
        ],
      ),
      body: _loading && _invoices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: () => _loadInvoices(refresh: true))
              : _invoices.isEmpty
                  ? _EmptyState(onCreate: _navigateToCreate)
                  : RefreshIndicator(
                      onRefresh: () => _loadInvoices(refresh: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _invoices.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _invoices.length) {
                            return _loadMore();
                          }
                          return _InvoiceListItem(
                            invoice: _invoices[index],
                            onTap: () => _navigateToDetail(_invoices[index]),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceCreateScreen(
          businessId: widget.businessId,
          businessName: widget.businessName,
        ),
      ),
    ).then((_) => _loadInvoices(refresh: true));
  }

  void _navigateToDetail(InvoiceModel invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(
          businessId: widget.businessId,
          businessName: widget.businessName,
          invoiceId: invoice.id,
        ),
      ),
    );
  }

  Widget _loadMore() {
    if (!_hasMore || _loading) return const SizedBox();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => _loadInvoices(),
          child: const Text('Charger plus'),
        ),
      ),
    );
  }
}

class _InvoiceListItem extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;

  const _InvoiceListItem({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Statut badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: invoice.statutColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: invoice.statutColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  invoice.statutDisplay,
                  style: TextStyle(
                    color: invoice.statutColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          invoice.numero,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            invoice.typeDisplay,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${invoice.itemNom} • ${invoice.clientNom}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.montantTotalFormate,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
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
            FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Réessayer'), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Aucune facture', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Créez votre première facture pour une réservation', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Créer une facture'), onPressed: onCreate),
          ],
        ),
      ),
    );
  }
}