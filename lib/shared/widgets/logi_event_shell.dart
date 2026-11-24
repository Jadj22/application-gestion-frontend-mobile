import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_bottom_nav.dart';
import 'sync_status_banner.dart';

/// Shell responsive LogiEvent Pro : TopBar + Sidebar (desktop) / BottomNav (mobile).
///
/// Sur une page secondaire (`showNavigation: false`), la navigation principale
/// est masquée et une AppBar « Retour + titre » est affichée.
class LogiEventShell extends StatelessWidget {
  final int navIndex;
  final Widget body;
  final ValueChanged<int>? onNavTap;
  final bool showAppBar;
  final bool showNavigation;
  final String? pageTitle;
  final Widget? bottomNavigationBar;

  const LogiEventShell({
    super.key,
    required this.navIndex,
    required this.body,
    this.onNavTap,
    this.showAppBar = true,
    this.showNavigation = true,
    this.pageTitle,
    this.bottomNavigationBar,
  });

  static const double _breakpoint = 768;
  static const double _sidebarWidth = 256;

  @override
  Widget build(BuildContext context) {
    if (!showNavigation) {
      return Scaffold(
        backgroundColor: AppColors.dashSurface,
        appBar: _buildSecondaryAppBar(context),
        body: _withSyncBanner(body),
        bottomNavigationBar: bottomNavigationBar,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _breakpoint;
        return Scaffold(
          backgroundColor: AppColors.dashSurface,
          appBar: isWide || !showAppBar ? null : _buildMobileAppBar(context),
          body: isWide
              ? Column(
                  children: [
                    _DesktopTopBar(onNavTap: onNavTap, navIndex: navIndex),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Sidebar(
                            currentIndex: navIndex,
                            onTap: onNavTap ?? (_) {},
                          ),
                          Expanded(child: _withSyncBanner(body)),
                        ],
                      ),
                    ),
                  ],
                )
              : _withSyncBanner(body),
          bottomNavigationBar: isWide
              ? null
              : AppBottomNav(
                  currentIndex: navIndex,
                  onTap: onNavTap ?? (_) {},
                ),
        );
      },
    );
  }

  /// Coiffe le contenu de l'indicateur de synchronisation.
  ///
  /// Posé une seule fois dans la coquille plutôt qu'écran par écran :
  /// l'utilisateur doit pouvoir savoir ce qui attend d'être envoyé depuis
  /// n'importe où dans l'application. Le bandeau s'efface de lui-même quand
  /// tout est synchronisé, et n'interrompt jamais le travail en cours.
  Widget _withSyncBanner(Widget content) => Column(
        children: [
          const SyncStatusBanner(),
          Expanded(child: content),
        ],
      );

  PreferredSizeWidget _buildSecondaryAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.dashSurfaceLowest,
      foregroundColor: AppColors.dashPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leadingWidth: 96,
      leading: TextButton.icon(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.dashPrimary),
        label: const Text(
          'Retour',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.dashPrimary,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.only(left: 8),
          foregroundColor: AppColors.dashPrimary,
        ),
      ),
      title: Text(
        pageTitle ?? '',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.dashPrimary,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.dashOutlineVariant),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.dashSurfaceLowest,
      foregroundColor: AppColors.dashPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Text(
        'LogiEvent Pro',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.dashPrimary,
          letterSpacing: -0.3,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {},
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today_outlined),
          tooltip: 'Réservations',
          onPressed: () => onNavTap?.call(3),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.dashOutlineVariant),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final int navIndex;
  final ValueChanged<int>? onNavTap;

  const _DesktopTopBar({required this.navIndex, this.onNavTap});

  static const _links = [
    (0, 'Dashboard'),
    (1, 'Inventaire'),
    (2, 'Entretien'),
    (3, 'Réservations'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceLowest,
        border: Border(bottom: BorderSide(color: AppColors.dashOutlineVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu, color: AppColors.dashOnSurfaceVariant),
          const SizedBox(width: 12),
          const Text(
            'LogiEvent Pro',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.dashPrimary,
            ),
          ),
          const Spacer(),
          ..._links.map((link) {
            final selected = link.$1 == navIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                onPressed: () => onNavTap?.call(link.$1),
                style: TextButton.styleFrom(
                  foregroundColor: selected
                      ? AppColors.dashPrimary
                      : AppColors.dashOnSurfaceVariant,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  link.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    decoration:
                        selected ? TextDecoration.underline : TextDecoration.none,
                    decorationColor: AppColors.dashPrimary,
                    decorationThickness: 2,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _Sidebar({required this.currentIndex, required this.onTap});

  static const _items = [
    (0, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Accueil'),
    (1, Icons.layers_outlined, Icons.layers_rounded, 'Inventaire'),
    (2, Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Réservations'),
    (3, Icons.build_outlined, Icons.build_rounded, 'Entretien'),
    (4, Icons.more_horiz_outlined, Icons.more_horiz_rounded, 'Plus'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: LogiEventShell._sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceLowest,
        border: Border(right: BorderSide(color: AppColors.dashOutlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _items.map((item) {
          final selected = item.$1 == currentIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: selected
                  ? AppColors.dashSecondaryContainer.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onTap(item.$1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        selected ? item.$3 : item.$2,
                        size: 22,
                        color: selected
                            ? AppColors.dashSecondary
                            : AppColors.dashOnSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.$4,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.dashSecondary
                              : AppColors.dashOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// En-tête de page avec flèche retour + titre (maquette LogiEvent).
class LogiEventPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const LogiEventPageHeader({
    super.key,
    required this.title,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.dashOnSurfaceVariant,
          onPressed: onBack ?? () => Navigator.maybePop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            hoverColor: AppColors.dashSurfaceContainer,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: AppTextStyles.h2.copyWith(
            color: AppColors.dashOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Carte avec bordure outline — style LogiEvent.
class LogiEventCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const LogiEventCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: child,
    );
  }
}
