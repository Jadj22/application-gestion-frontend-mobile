import '../../../core/network/api_endpoints.dart';
import '../../../core/offline/derived_cache.dart';
import '../../../features/auth/data/models/user.dart';

/// Données de la page d'accueil (S 7-04) — synthèse dashboard Stitch.
///
/// Source principale : GET /dashboard/
///
/// Le tableau de bord est un agrégat que seul le serveur sait calculer : il
/// croise stock, entretien, réservations et alertes sur l'ensemble du business.
/// Il n'est donc pas stocké comme une entité mais conservé tel quel, et servi
/// depuis sa dernière copie quand le réseau manque — sans quoi l'écran
/// d'accueil, premier écran de l'application, serait vide hors ligne.
class HomeRepository {
  final DerivedCache _derived;

  HomeRepository(this._derived);

  Future<HomeDashboard> load(String businessId, {bool refresh = false}) async {
    final dashboard = await _derived.object(
      'dashboard.$businessId',
      ApiEndpoints.businessDashboard(businessId),
      refresh: refresh,
    );

    final articles = dashboard['articles'] as Map<String, dynamic>? ?? const {};
    final stock = dashboard['stock'] as Map<String, dynamic>? ?? const {};
    final reservations =
        dashboard['reservations'] as Map<String, dynamic>? ?? const {};

    final recentAlerts = ((dashboard['alertes_recents'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HomeAlert.fromJson)
        .toList();

    final activities = ((dashboard['activite_recents'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ActivityEntry.fromJson)
        .toList();

    final decisionsCount =
        ((dashboard['decisions_recents'] as List?) ?? const []).length;

    final inventaireActif = dashboard['inventaire_actif'] as Map<String, dynamic>?;

    return HomeDashboard(
      totalStock: (stock['total'] as num?)?.toInt() ?? 0,
      disponibleCount: (stock['disponibles'] as num?)?.toInt() ?? 0,
      enLocationCount: (stock['en_location'] as num?)?.toInt() ?? 0,
      endommageCount: (stock['endommages'] as num?)?.toInt() ?? 0,
      articlesTotal: (articles['total'] as num?)?.toInt() ?? 0,
      enEntretienCount: (articles['en_entretien'] as num?)?.toInt() ?? 0,
      entretienPartielCount: (articles['entretien_partiel'] as num?)?.toInt() ?? 0,
      aEntretenirCount: (articles['a_entretenir'] as num?)?.toInt() ?? 0,
      aVerifierCount: (articles['a_verifier'] as num?)?.toInt() ?? 0,
      aControlerCount: (articles['a_controler'] as num?)?.toInt() ?? 0,
      conflitsReservation: (dashboard['conflits_reservation'] as num?)?.toInt() ?? 0,
      tachesEnCours: (dashboard['taches_en_cours'] as num?)?.toInt() ?? 0,
      reservationsEnAttente: (reservations['en_attente'] as num?)?.toInt() ?? 0,
      reservationsEnCours: (reservations['en_cours'] as num?)?.toInt() ?? 0,
      decisionsRecentes: decisionsCount,
      inventaireActif: inventaireActif != null,
      alerts: recentAlerts,
      activities: activities,
      actions: _buildActions(
        maintenanceNeeded: (articles['a_entretenir'] as num?)?.toInt() ?? 0,
        enEntretien: (articles['en_entretien'] as num?)?.toInt() ?? 0,
        aVerifier: (articles['a_verifier'] as num?)?.toInt() ?? 0,
        aControler: (articles['a_controler'] as num?)?.toInt() ?? 0,
        conflits: (dashboard['conflits_reservation'] as num?)?.toInt() ?? 0,
        reservationsEnCours: (reservations['en_cours'] as num?)?.toInt() ?? 0,
        decisionsRecentes: decisionsCount,
        inventaireActif: inventaireActif != null,
      ),
    );
  }

  List<DashboardAction> _buildActions({
    required int maintenanceNeeded,
    required int enEntretien,
    required int aVerifier,
    required int aControler,
    required int conflits,
    required int reservationsEnCours,
    required int decisionsRecentes,
    required bool inventaireActif,
  }) {
    final actions = <DashboardAction>[];

    final maintenanceTotal = maintenanceNeeded + enEntretien;
    if (maintenanceTotal > 0) {
      actions.add(DashboardAction(
        kind: ActionKind.maintenance,
        title: 'Entretien Requis',
        priority: ActionPriority.high,
        message:
            '$maintenanceTotal article${maintenanceTotal > 1 ? 's' : ''} nécessite${maintenanceTotal > 1 ? 'nt' : ''} une planification d\'entretien.',
      ));
    }

    if (inventaireActif || aVerifier > 0 || aControler > 0) {
      final count = aVerifier + aControler + (inventaireActif ? 1 : 0);
      actions.add(DashboardAction(
        kind: ActionKind.stockCheck,
        title: 'Vérification du Stock',
        priority: ActionPriority.medium,
        message: inventaireActif
            ? 'Un inventaire est en cours — poursuivre le comptage.'
            : '$count élément${count > 1 ? 's' : ''} signalé${count > 1 ? 's' : ''} pour vérification manuelle.',
      ));
    }

    if (reservationsEnCours > 0) {
      actions.add(DashboardAction(
        kind: ActionKind.returnCheck,
        title: 'Contrôle de Retour',
        priority: ActionPriority.medium,
        message:
            '$reservationsEnCours location${reservationsEnCours > 1 ? 's' : ''} en cours en attente de contrôle qualité.',
      ));
    }

    if (conflits > 0) {
      actions.add(DashboardAction(
        kind: ActionKind.reservationConflict,
        title: 'Conflit de Réservation',
        priority: ActionPriority.critical,
        message:
            '$conflits conflit${conflits > 1 ? 's' : ''} de réservation actif${conflits > 1 ? 's' : ''} détecté${conflits > 1 ? 's' : ''}.',
      ));
    }

    if (decisionsRecentes > 0) {
      actions.add(DashboardAction(
        kind: ActionKind.exception,
        title: 'Décisions Exceptionnelles',
        priority: ActionPriority.high,
        message:
            '$decisionsRecentes décision${decisionsRecentes > 1 ? 's' : ''} récente${decisionsRecentes > 1 ? 's' : ''} à consulter.',
      ));
    }

    return actions;
  }
}

/// Synthèse complète de l'accueil, prête à l'affichage.
class HomeDashboard {
  final int totalStock;
  final int disponibleCount;
  final int enLocationCount;
  final int endommageCount;
  final int articlesTotal;
  final int enEntretienCount;
  final int entretienPartielCount;
  final int aEntretenirCount;
  final int aVerifierCount;
  final int aControlerCount;
  final int conflitsReservation;
  final int tachesEnCours;
  final int reservationsEnAttente;
  final int reservationsEnCours;
  final int decisionsRecentes;
  final bool inventaireActif;
  final List<HomeAlert> alerts;
  final List<ActivityEntry> activities;
  final List<DashboardAction> actions;

  const HomeDashboard({
    required this.totalStock,
    required this.disponibleCount,
    required this.enLocationCount,
    required this.endommageCount,
    required this.articlesTotal,
    required this.enEntretienCount,
    required this.entretienPartielCount,
    required this.aEntretenirCount,
    required this.aVerifierCount,
    required this.aControlerCount,
    required this.conflitsReservation,
    required this.tachesEnCours,
    required this.reservationsEnAttente,
    required this.reservationsEnCours,
    required this.decisionsRecentes,
    required this.inventaireActif,
    required this.alerts,
    required this.activities,
    required this.actions,
  });

  int get entretienCount =>
      enEntretienCount + entretienPartielCount + aEntretenirCount + tachesEnCours;

  int get aVerifierTotal => aVerifierCount + aControlerCount;
}

enum ActionKind { maintenance, stockCheck, returnCheck, reservationConflict, exception }

enum ActionPriority { critical, high, medium }

class DashboardAction {
  final ActionKind kind;
  final String title;
  final ActionPriority priority;
  final String message;

  const DashboardAction({
    required this.kind,
    required this.title,
    required this.priority,
    required this.message,
  });
}

class ActivityEntry {
  final String id;
  final String action;
  final User? acteur;
  final String cible;
  final DateTime? createdAt;

  const ActivityEntry({
    required this.id,
    required this.action,
    this.acteur,
    this.cible = '',
    this.createdAt,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: json['id'] as String,
        action: (json['action'] as String?) ?? '',
        acteur: json['acteur'] is Map<String, dynamic>
            ? User.fromJson(json['acteur'] as Map<String, dynamic>)
            : null,
        cible: (json['cible'] as String?) ?? '',
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? ''),
      );

  String get actorLabel {
    final user = acteur;
    if (user == null) return 'Équipe';
    if (user.firstName.isNotEmpty) return user.firstName;
    return user.displayName;
  }

  String get summary {
    switch (action) {
      case 'STOCK.ENTREE':
        return 'Entrée de stock enregistrée${cible.isNotEmpty ? ' — $cible' : ''}.';
      case 'STOCK.SORTIE':
        return 'Sortie de stock${cible.isNotEmpty ? ' — $cible' : ''}.';
      case 'STOCK.RETOUR':
        return 'Retour enregistré${cible.isNotEmpty ? ' — $cible' : ''}.';
      case 'STOCK.DOMMAGE':
        return 'Dommage signalé${cible.isNotEmpty ? ' — $cible' : ''}.';
      case 'TASK.CLOTURE':
        return 'Entretien terminé${cible.isNotEmpty ? ' — $cible' : ''}.';
      case 'DECISION.EXCEPTION':
        return 'Décision exceptionnelle${cible.isNotEmpty ? ' — $cible' : ''}.';
      case 'RESERVATION.TERMINEE':
        return 'Réservation clôturée${cible.isNotEmpty ? ' — $cible' : ''}.';
      default:
        return cible.isNotEmpty ? cible : action.replaceAll('.', ' ').toLowerCase();
    }
  }
}

/// Gravité d'une alerte prioritaire.
enum AlertSeverity { maintenance, critical }

/// Alerte prioritaire — `AlertSerializer` du backend.
class HomeAlert {
  final String id;
  final String itemNom;
  final String code;
  final String mode;
  final String message;
  final DateTime? createdAt;

  const HomeAlert({
    required this.id,
    required this.itemNom,
    required this.code,
    required this.mode,
    required this.message,
    this.createdAt,
  });

  factory HomeAlert.fromJson(Map<String, dynamic> json) => HomeAlert(
        id: json['id'] as String,
        itemNom: (json['item_nom'] as String?) ?? '',
        code: (json['code'] as String?) ?? '',
        mode: (json['mode'] as String?) ?? 'AVERTISSEMENT',
        message: (json['message'] as String?) ?? '',
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? ''),
      );

  AlertSeverity get severity =>
      mode == 'BLOCAGE' ? AlertSeverity.critical : AlertSeverity.maintenance;

  String get title {
    switch (code) {
      case 'ARTICLE_EN_ENTRETIEN':
        return 'Article en entretien';
      case 'ENTRETIEN_PARTIEL':
        return 'Entretien partiel';
      case 'ARTICLE_A_VERIFIER':
        return 'Article à vérifier';
      default:
        return itemNom.isEmpty ? 'Alerte' : itemNom;
    }
  }
}

/// Statut de disponibilité d'un article (ligne /stock/).
enum ItemStatus { available, low, unavailable }

class RecentItemModel {
  final String id;
  final String name;
  final String sku;
  final int total;
  final ItemStatus status;

  const RecentItemModel({
    required this.id,
    required this.name,
    required this.sku,
    required this.total,
    required this.status,
  });

  factory RecentItemModel.fromJson(Map<String, dynamic> json) {
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final disponibles = (json['disponibles'] as num?)?.toInt() ?? 0;
    final itemStatut = (json['statut'] as String?) ?? 'ACTIF';
    final status = itemStatut == 'INACTIF' || (total == 0 && disponibles == 0)
        ? ItemStatus.unavailable
        : disponibles == 0
            ? ItemStatus.low
            : ItemStatus.available;
    return RecentItemModel(
      id: (json['item_id'] as String?) ?? '',
      name: (json['nom'] as String?) ?? '',
      sku: (json['reference'] as String?) ?? '',
      total: total,
      status: status,
    );
  }
}
