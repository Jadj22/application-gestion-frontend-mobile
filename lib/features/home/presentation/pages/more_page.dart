import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../analytics/presentation/pages/analytics_screen.dart';
import '../../../auth/data/models/user.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../items/data/models/item.dart';
import '../../../items/presentation/pages/item_detail_screen.dart';
import '../../../items/presentation/pages/qr_export_page.dart';
import '../../../maintenance/presentation/pages/qr_scanner_screen.dart';
import '../../../maintenance/presentation/pages/recurring_tasks_screen.dart';
import '../../../maintenance/presentation/pages/reminders_screen.dart';
import '../../../members/presentation/pages/members_page.dart';
import '../../../notifications/presentation/pages/notifications_screen.dart';
import 'help_page.dart';

/// Onglet « Plus » — profil, équipe, aide et déconnexion.
class MorePage extends StatelessWidget {
  final VoidCallback onStartGuide;

  const MorePage({super.key, required this.onStartGuide});

  /// Ouvre le scanner puis, si un article a été reconnu, sa fiche détaillée.
  Future<void> _openScanner(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    final item = result?['item'];
    if (item is! ItemModel || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(itemId: item.id, initialNom: item.nom),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final session = context.read<SessionController>();
    final pending = await session.pendingBeforeLogout();
    final hasPending = pending > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: Text(
          hasPending
              ? '$pending modification${pending > 1 ? 's' : ''} en attente de synchronisation. '
                  'Voulez-vous quand même vous déconnecter (elles seront perdues) ?'
              : 'Vous devrez vous reconnecter pour accéder à votre inventaire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Se déconnecter',
              style: TextStyle(color: hasPending ? AppColors.dangerText : AppColors.dangerText),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await session.logout(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final businessName = session.currentBusiness?.nom;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Plus', style: AppTextStyles.h1),
          const SizedBox(height: 4),
          const Text('Compte, équipe et aide.', style: AppTextStyles.body),
          const SizedBox(height: 20),
          _ProfileCard(user: user, businessName: businessName),
          const SizedBox(height: 24),
          const _SectionLabel('LIEN PUBLIC'),
          const SizedBox(height: 8),
          _PublicLinkCard(slug: session.currentBusiness?.slug ?? ''),
          const SizedBox(height: 24),
          const _SectionLabel('DÉCOUVRIR'),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.explore_outlined,
            iconColor: AppColors.primary,
            title: 'Guide de démarrage',
            subtitle: 'Découvrez les fonctionnalités principales',
            onTap: onStartGuide,
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.menu_book_outlined,
            iconColor: AppColors.primary,
            title: 'Comment fonctionne l\'application',
            subtitle: 'Le guide complet, section par section',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpPage()),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('ÉQUIPE'),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.group_outlined,
            iconColor: AppColors.dashOnSurfaceVariant,
            title: 'Membres & rôles',
            subtitle: 'Gérer les accès de votre équipe',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MembersPage()),
            ),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.notifications_outlined,
            iconColor: AppColors.dashOnSurfaceVariant,
            title: 'Notifications',
            subtitle: 'Vos alertes récentes',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('OUTILS'),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.analytics_outlined,
            iconColor: Colors.purple,
            title: 'Analytics',
            subtitle: 'Statistiques et tendances',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.receipt_long_outlined,
            iconColor: Colors.teal,
            title: 'Factures',
            subtitle: 'Gérer et consulter vos factures',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fonctionnalité non disponible')),
            ),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.repeat,
            iconColor: Colors.indigo,
            title: 'Tâches récurrentes',
            subtitle: 'Maintenances automatiques planifiées',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringTasksScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.alarm,
            iconColor: Colors.orange,
            title: 'Rappels',
            subtitle: 'Gérer vos rappels programmés',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.qr_code_scanner,
            iconColor: Colors.blueGrey,
            title: 'Scanner QR Code',
            subtitle: 'Accéder à un article par scan',
            onTap: () => _openScanner(context),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.qr_code_2,
            iconColor: Colors.deepPurple,
            title: 'Exporter QR Codes',
            subtitle: 'Générer PDF par catégorie',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrExportPage()),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('COMPTE'),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.logout,
            iconColor: AppColors.dangerText,
            title: 'Déconnexion',
            subtitle: null,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final User? user;
  final String? businessName;

  const _ProfileCard({required this.user, required this.businessName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              user?.initials ?? '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? '—',
                  style: AppTextStyles.h2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  businessName ?? user?.email ?? '',
                  style: AppTextStyles.body.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.fieldLabel);
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dashOutlineVariant),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dashOnSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.body.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                   size: 18, color: AppColors.dashOutline),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicLinkCard extends StatelessWidget {
  final String slug;

  const _PublicLinkCard({required this.slug});

  Future<void> _openUrl(BuildContext context, String urlString) async {
    if (urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun lien disponible pour ce commerce.')),
      );
      return;
    }

    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ouverture : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = slug.isNotEmpty ? '${AppConfig.webBaseUrl}/b/$slug' : '';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openUrl(context, url),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dashOutlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.language, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Votre vitrine en ligne',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dashOnSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Partagez ce lien avec vos clients',
                          style: AppTextStyles.body.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 18, color: AppColors.dashOutline),
                ],
              ),
              if (url.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          url,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.dashOnSurface,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        color: AppColors.primary,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lien copié !')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, size: 18),
                        color: AppColors.primary,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        onPressed: () => Share.share(url),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
