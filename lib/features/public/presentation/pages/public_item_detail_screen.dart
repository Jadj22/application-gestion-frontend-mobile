import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/public_item_model.dart';
import '../../data/repositories/public_catalog_repository.dart';
import '../../data/repositories/booking_request_repository.dart';
import '../widgets/availability_badge.dart';
import 'booking_request_create_screen.dart';

/// Fiche article public avec disponibilité et bouton demande (V1 + V2)
class PublicItemDetailScreen extends StatefulWidget {
  final String slug;
  final String businessName;
  final PublicItemModel item;
  final DateTime? selectedDateDebut;
  final DateTime? selectedDateFin;

  const PublicItemDetailScreen({
    super.key,
    required this.slug,
    required this.businessName,
    required this.item,
    this.selectedDateDebut,
    this.selectedDateFin,
  });

  @override
  State<PublicItemDetailScreen> createState() => _PublicItemDetailScreenState();
}

class _PublicItemDetailScreenState extends State<PublicItemDetailScreen> {
  late final PublicCatalogRepository _catalogRepo;
  late final BookingRequestRepository _bookingRepo;
  AvailabilityDetail? _availability;
  bool _loadingAvailability = false;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _catalogRepo = PublicCatalogRepository(apiClient);
    _bookingRepo = BookingRequestRepository(apiClient);

    if (widget.selectedDateDebut != null && widget.selectedDateFin != null) {
      _loadAvailability();
    }
  }

  Future<void> _loadAvailability() async {
    setState(() => _loadingAvailability = true);
    try {
      _availability = await _catalogRepo.getAvailability(
        slug: widget.slug,
        itemId: widget.item.id,
        dateDebut: widget.selectedDateDebut!,
        dateFin: widget.selectedDateFin!,
      );
    } catch (e) {
      debugPrint('Erreur dispo: $e');
    } finally {
      if (mounted) setState(() => _loadingAvailability = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.nom),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Image + header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  item.photoUrl != null
                      ? Image.network(
                          item.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom + référence
                  Text(
                    item.nom,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (item.reference != null && item.reference!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Référence: ${item.reference}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ),
                  if (item.categoryNom != null && item.categoryNom!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text(item.categoryNom!),
                        avatar: const Icon(Icons.category_outlined, size: 16),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Description publique
                  if (item.publicDescription.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.publicDescription,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Prix + dispo
                  Row(
                    children: [
                      Text(
                        item.prixFormate,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      AvailabilityBadge(
                        disponible: item.disponible ?? _availability?.disponible,
                        peutReserver: item.peutReserver ?? _availability?.peutReserver,
                        showLabel: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Disponibilité détaillée si dates sélectionnées
                  if (widget.selectedDateDebut != null && widget.selectedDateFin != null) ...[
                    Text(
                      'Disponibilité du ${DateFormat('dd/MM/yyyy').format(widget.selectedDateDebut!)} au ${DateFormat('dd/MM/yyyy').format(widget.selectedDateFin!)}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _loadingAvailability
                        ? const Center(child: CircularProgressIndicator())
                        : _availability != null
                            ? _AvailabilityDetailCard(availability: _availability!)
                            : const Text('Impossible de charger la disponibilité'),
                    const SizedBox(height: 24),
                  ],

                  // Bouton demander
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('Demander une location', style: TextStyle(fontSize: 16)),
                      onPressed: (item.peutReserver ?? _availability?.peutReserver ?? false)
                          ? () => _openBookingRequest()
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // QR Code
                  if (item.qrCode != null) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Code QR',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            color: Colors.white,
                            child: Center(
                              child: Text(
                                'QR: ${item.qrCode}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scannez pour voir cet article',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _availability != null && _availability!.detailBookingRequests.isNotEmpty
          ? _BookingRequestsBanner(availability: _availability!)
          : null,
    );
  }

  void _openBookingRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingRequestCreateScreen(
          slug: widget.slug,
          businessName: widget.businessName,
          item: widget.item,
          selectedDateDebut: widget.selectedDateDebut,
          selectedDateFin: widget.selectedDateFin,
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
      );
}

/// Carte détail disponibilité
class _AvailabilityDetailCard extends StatelessWidget {
  final AvailabilityDetail availability;

  const _AvailabilityDetailCard({required this.availability});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _AvailRow('Stock total', '${availability.totalStock}'),
            _AvailRow('Disponible', '${availability.disponible}', highlight: true),
            _AvailRow('Réservations en cours', '${availability.reservesPendantPeriode}'),
            if (availability.bookingRequestsPendantes > 0)
              _AvailRow('Demandes en attente', '${availability.bookingRequestsPendantes}'),
            if (availability.enEntretien > 0)
              _AvailRow('En entretien', '${availability.enEntretien}'),
            _AvailRow('Stock physique', '${availability.enStockPhysique}'),
          ],
        ),
      ),
    );
  }
}

class _AvailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _AvailRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
              color: highlight ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bannière demandes en attente
class _BookingRequestsBanner extends StatelessWidget {
  final AvailabilityDetail availability;

  const _BookingRequestsBanner({required this.availability});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = availability.detailBookingRequests.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count demande${count > 1 ? 's' : ''} en attente pour ces dates',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange[800]),
            ),
          ),
          TextButton(
            onPressed: () {}, // TODO: ouvrir détail
            child: const Text('Voir'),
          ),
        ],
      ),
    );
  }
}