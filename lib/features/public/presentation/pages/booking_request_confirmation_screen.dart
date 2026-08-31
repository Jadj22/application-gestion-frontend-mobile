import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/public_item_model.dart';
import '../../data/models/booking_request_model.dart';
import '../../data/repositories/booking_request_repository.dart';
import 'booking_request_detail_screen.dart';

/// Écran confirmation après envoi demande (V2)
class BookingRequestConfirmationScreen extends StatelessWidget {
  final String slug;
  final String businessName;
  final BookingRequestCreateResult result;
  final PublicItemModel item;

  const BookingRequestConfirmationScreen({
    super.key,
    required this.slug,
    required this.businessName,
    required this.result,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demande envoyée'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Succès
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            ),
            const SizedBox(height: 24),
            Text(
              'Demande envoyée !',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'L\'équipe de $businessName a été notifiée.\nVous recevrez une réponse sous peu.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Récap
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: item.photoUrl != null
                                ? Image.network(item.photoUrl!, fit: BoxFit.cover)
                                : Container(color: Colors.grey[200]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.nom, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('Demande #${result.id.substring(0, 8).toUpperCase()}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    _InfoRow('Article', item.nom),
                    _InfoRow('Prix', item.prixFormate),
                    _InfoRow('Statut', 'En attente de traitement', valueColor: Colors.orange),
                    _InfoRow('Lien de suivi', 'Disponible 7 jours'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Boutons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Suivre ma demande'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingRequestDetailScreen(
                          slug: slug,
                          businessName: businessName,
                          token: result.accessToken,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('Retour à l\'accueil'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}