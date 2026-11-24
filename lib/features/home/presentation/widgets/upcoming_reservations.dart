import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../reservations/data/models/reservation.dart';

/// Section « À venir » avec cartes de réservations.
class UpcomingReservations extends StatelessWidget {
  final List<ReservationModel> reservations;
  final VoidCallback onSeeAll;
  final ValueChanged<ReservationModel>? onTapReservation;
  final int maxItems;

  const UpcomingReservations({
    super.key,
    required this.reservations,
    required this.onSeeAll,
    this.onTapReservation,
    this.maxItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    final items = reservations.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
          child: Row(
            children: [
              Text(
                'À venir',
                style: AppTextStyles.h2.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Tout voir'),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 32,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 10),
                Text(
                  'Aucune réservation programmée',
                  style: AppTextStyles.h3.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Les prochaines locations apparaîtront ici.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...items.map(
            (resa) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: ReservationCard(
                reservation: resa,
                onTap: onTapReservation == null
                    ? null
                    : () => onTapReservation!(resa),
              ),
            ),
          ),
      ],
    );
  }
}

class ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  final VoidCallback? onTap;

  const ReservationCard({
    super.key,
    required this.reservation,
    this.onTap,
  });

  Color get _statusDot {
    switch (reservation.statut) {
      case 'VALIDEE':
      case 'EN_COURS':
        return AppColors.success;
      case 'EN_ATTENTE':
        return AppColors.warning;
      case 'ANNULEE':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (reservation.statut) {
      case 'VALIDEE':
        return 'Validée';
      case 'EN_COURS':
        return 'En cours';
      case 'EN_ATTENTE':
        return 'En attente';
      case 'ANNULEE':
        return 'Annulée';
      case 'TERMINEE':
        return 'Terminée';
      default:
        return reservation.statutLabel;
    }
  }

  String get _title {
    final motif = reservation.motif.trim();
    if (motif.isNotEmpty) return motif;
    return reservation.itemNom.isNotEmpty
        ? reservation.itemNom
        : reservation.reference;
  }

  String get _subtitle {
    final parts = <String>[];
    if (reservation.itemNom.isNotEmpty && reservation.motif.trim().isNotEmpty) {
      parts.add(
        '${reservation.quantite} ${reservation.itemNom}',
      );
    } else if (reservation.quantite > 0) {
      parts.add('${reservation.quantite} unité${reservation.quantite > 1 ? 's' : ''}');
    }
    final contact = reservation.contactNom.trim();
    if (contact.isNotEmpty) parts.add(contact);
    final livraison = reservation.livraisonPrevueLe;
    if (livraison != null) {
      parts.add('Livraison ${livraison.hour}h');
    } else if (reservation.lieuNom.trim().isNotEmpty) {
      parts.add(reservation.lieuNom.trim());
    }
    return parts.isEmpty ? 'Réservation' : parts.join(' · ');
  }

  static const _months = [
    'JAN.', 'FÉV.', 'MARS', 'AVR.', 'MAI', 'JUIN',
    'JUIL.', 'AOÛT', 'SEPT.', 'OCT.', 'NOV.', 'DÉC.',
  ];

  String _relativeLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final days = target.difference(today).inDays;
    if (days == 0) return "Aujourd'hui";
    if (days == 1) return 'Demain';
    if (days > 1) return 'Dans $days jours';
    if (days == -1) return 'Hier';
    return 'Il y a ${-days} jours';
  }

  @override
  Widget build(BuildContext context) {
    final date = reservation.dateDebut ?? reservation.livraisonPrevueLe;
    final month = date == null ? '—' : _months[date.month - 1];
    final day = date == null ? '—' : '${date.day}';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _statusDot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _statusLabel,
                                style: AppTextStyles.captionBold.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (date != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _relativeLabel(date),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.dashOutline,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
