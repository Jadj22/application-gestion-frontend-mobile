import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/logi_event_shell.dart';

/// Explique à l'utilisateur comment utiliser pleinement l'application,
/// section par section — accessible depuis l'onglet Plus.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LogiEventShell(
      navIndex: 4,
      showNavigation: false,
      pageTitle: 'Comment fonctionne DODOME',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            const Text('Bienvenue sur DODOME', style: AppTextStyles.h1),
            const SizedBox(height: 6),
            Text(
              'Voici comment tirer le meilleur de chaque section de '
              'l\'application, étape par étape.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 20),
            const _HelpSection(
              icon: Icons.dashboard_outlined,
              title: 'Tableau de bord',
              summary: 'Votre vue d\'ensemble au quotidien.',
              points: [
                'Suivez en un coup d\'œil le stock total, disponible, en '
                    'location, en entretien, endommagé et à vérifier.',
                'Touchez une carte de statistique pour ouvrir directement '
                    'l\'inventaire filtré correspondant.',
                'Utilisez « Nouvelle action » pour ajouter rapidement un '
                    'article, une entrée de stock ou une catégorie.',
                'Consultez les actions à faire et le journal d\'activité '
                    'pour ne rien manquer.',
              ],
            ),
            const _HelpSection(
              icon: Icons.inventory_2_outlined,
              title: 'Inventaire',
              summary: 'Votre catalogue et l\'état réel du stock.',
              points: [
                'Onglet Catalogue : consultez, recherchez et filtrez vos '
                    'articles par catégorie.',
                'Onglet Stock : voyez précisément ce qui est disponible, '
                    'en location, endommagé ou à vérifier.',
                'Ajoutez un article avec une photo (l\'IA peut générer sa '
                    'description automatiquement) et son SKU.',
                'Enregistrez une entrée de stock quand du matériel arrive '
                    'ou revient.',
              ],
            ),
            const _HelpSection(
              icon: Icons.build_outlined,
              title: 'Entretien',
              summary: 'Gardez votre matériel en bon état.',
              points: [
                'Créez une tâche d\'entretien pour un article et suivez sa '
                    'procédure étape par étape.',
                'Basculez entre Notes et Tâches pour organiser votre suivi.',
                'Clôturez une tâche une fois toutes les étapes validées.',
              ],
            ),
            const _HelpSection(
              icon: Icons.event_available_outlined,
              title: 'Réservations',
              summary: 'Réservez du matériel pour un événement.',
              points: [
                'Choisissez une période — avec des raccourcis « ce '
                    'week-end », « 3 jours », « 1 semaine ».',
                'Sélectionnez plusieurs articles et leurs quantités : '
                    'recherchez et filtrez par catégorie pour aller vite.',
                'La réservation est validée dans son ensemble : si un seul '
                    'article n\'est pas disponible sur la période, rien '
                    'n\'est réservé.',
                'Suivez le statut de chaque article : en attente → '
                    'validée → en cours → terminée.',
                'Au retour du matériel, utilisez « Contrôler le retour » '
                    'pour indiquer ce qui est rendu, abîmé ou perdu.',
              ],
            ),
            const _HelpSection(
              icon: Icons.group_outlined,
              title: 'Membres & rôles',
              summary: 'Travaillez à plusieurs, en toute sécurité.',
              points: [
                'Invitez vos collègues par email ou par code d\'invitation.',
                'Chaque membre a un rôle avec des permissions précises '
                    '(voir, gérer le stock, valider une réservation...).',
                'Les actions restent tracées : vous savez toujours qui a '
                    'fait quoi.',
              ],
            ),
            const _HelpSection(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              summary: 'Restez informé en temps réel.',
              points: [
                'Recevez une alerte pour les nouvelles réservations, '
                    'validations et retours.',
                'Accédez à vos notifications depuis la cloche du tableau '
                    'de bord ou depuis Plus.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String summary;
  final List<String> points;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.dashOnSurface,
            ),
          ),
          subtitle: Text(summary, style: AppTextStyles.body.copyWith(fontSize: 12)),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            point,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
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
