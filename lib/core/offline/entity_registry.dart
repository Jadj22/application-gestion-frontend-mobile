import '../network/api_endpoints.dart';

/// Stratégie de résolution de conflit appliquée à un type d'entité.
///
/// Le choix n'est volontairement pas global : il dépend de la nature de la
/// donnée (cf. `docs/OFFLINE_FIRST.md`, section « Conflits »).
enum ConflictStrategy {
  /// La version serveur écrase la version locale. Pour les données dont le
  /// serveur est seul propriétaire (statuts calculés, agrégats, workflow).
  serverWins,

  /// La version locale gagne. Pour les faits saisis par l'utilisateur que
  /// personne d'autre ne modifie en parallèle (journaux, commentaires).
  clientWins,

  /// La plus récente des deux gagne (comparaison des `updated_at`).
  lastWriteWins,

  /// Fusion champ par champ : seuls les champs réellement modifiés en local
  /// (diff avec la copie serveur de référence) écrasent la version serveur.
  mergeFields,

  /// Le conflit est matérialisé et présenté à l'utilisateur.
  manual,
}

/// Ce qu'une entité autorise hors ligne.
enum OfflineCapability {
  /// CRUD complet hors ligne.
  full,

  /// Lecture hors ligne, écriture uniquement en ligne (sécurité, e-mails,
  /// services tiers).
  readOnly,

  /// Aucune donnée locale : l'opération exige le réseau.
  onlineOnly,
}

/// Description d'un type d'entité synchronisable.
///
/// C'est le point unique de vérité du moteur de synchronisation : endpoints,
/// ordre de passage, stratégie de conflit et capacité hors ligne. Ajouter une
/// entité au projet revient à ajouter une entrée dans [EntityRegistry].
class EntityDescriptor {
  /// Identifiant technique, utilisé comme clé dans la base locale.
  final String type;

  /// Libellé lisible, utilisé dans les messages de l'UI.
  final String label;

  /// Chemin de la collection : `(businessId) => '/businesses/<id>/items/'`.
  final String Function(String businessId) collectionPath;

  /// Chemin d'un élément, ou null si l'entité n'expose pas de détail
  /// (collections append-only comme les mouvements de stock).
  final String Function(String businessId, String id)? itemPath;

  /// Ordre de passage dans la file : les petites valeurs partent d'abord.
  /// Une catégorie doit exister avant l'article qui la référence, l'article
  /// avant la tâche d'entretien qui le cible, etc.
  final int priority;

  final ConflictStrategy conflictStrategy;
  final OfflineCapability capability;

  /// Champs dont le serveur est propriétaire : jamais écrasés par une valeur
  /// locale lors d'une fusion, et retirés des payloads envoyés.
  final Set<String> serverOwnedFields;

  /// Champs du payload qui référencent une autre entité, et donc susceptibles
  /// de contenir un identifiant local temporaire à réécrire avant l'envoi.
  /// `{'item_id': 'item'}` se lit « la clé item_id référence une entité item ».
  final Map<String, String> references;

  /// L'entité est-elle immuable une fois créée ? (journal, historique)
  final bool appendOnly;

  /// Types dont la copie locale devient suspecte quand cette entité change.
  ///
  /// Le serveur recalcule des données dérivées à chaque écriture : créer un
  /// article change l'état du stock, un mouvement change les deux. Sans cette
  /// liste, l'écran continuerait d'afficher la version d'avant jusqu'à
  /// expiration du délai de fraîcheur — un article tout juste créé
  /// apparaîtrait « épuisé », un mouvement de stock resterait invisible.
  final Set<String> invalidates;

  const EntityDescriptor({
    required this.type,
    required this.label,
    required this.collectionPath,
    this.itemPath,
    required this.priority,
    required this.conflictStrategy,
    this.capability = OfflineCapability.full,
    this.serverOwnedFields = const {},
    this.references = const {},
    this.appendOnly = false,
    this.invalidates = const {},
  });

  bool get writableOffline => capability == OfflineCapability.full;
}

/// Catalogue des entités de l'application.
class EntityRegistry {
  EntityRegistry._();

  /// Champs présents dans quasiment toutes les réponses DRF et dont le
  /// serveur est l'unique propriétaire.
  static const _commonServerFields = {
    'id',
    'created_at',
    'updated_at',
    'business',
    'business_id',
  };

  static const category = EntityDescriptor(
    type: 'category',
    label: 'Catégorie',
    collectionPath: ApiEndpoints.businessCategories,
    itemPath: ApiEndpoints.businessCategory,
    priority: 10,
    // Une catégorie est un libellé saisi par l'utilisateur : la modification
    // locale est intentionnelle et ne dépend d'aucun calcul serveur.
    conflictStrategy: ConflictStrategy.mergeFields,
    serverOwnedFields: _commonServerFields,
  );

  static const item = EntityDescriptor(
    type: 'item',
    label: 'Article',
    collectionPath: ApiEndpoints.businessItems,
    itemPath: ApiEndpoints.businessItem,
    priority: 20,
    // La fiche article mélange saisie utilisateur (nom, prix, description) et
    // état calculé côté serveur (statut, stock, photos) : seuls les champs
    // réellement édités en local doivent partir.
    conflictStrategy: ConflictStrategy.mergeFields,
    serverOwnedFields: {
      ..._commonServerFields,
      'statut',
      'qr_code',
      'photos',
      'category',
      'stock',
      'quantite',
      'quantite_disponible',
    },
    references: {'category_id': 'category'},
    invalidates: {'stock_state'},
  );

  static const procedure = EntityDescriptor(
    type: 'procedure',
    label: 'Procédure',
    collectionPath: ApiEndpoints.businessProcedures,
    itemPath: ApiEndpoints.businessProcedure,
    priority: 20,
    conflictStrategy: ConflictStrategy.mergeFields,
    serverOwnedFields: {..._commonServerFields, 'steps'},
  );

  static const maintenanceTask = EntityDescriptor(
    type: 'maintenance_task',
    label: "Tâche d'entretien",
    collectionPath: ApiEndpoints.businessMaintenanceTasks,
    itemPath: ApiEndpoints.businessMaintenanceTask,
    priority: 30,
    // Le workflow (statut, étapes, clôture) est piloté par le serveur, qui
    // applique RM-11 ; en cas de divergence, le serveur fait foi.
    conflictStrategy: ConflictStrategy.serverWins,
    serverOwnedFields: {
      ..._commonServerFields,
      'statut',
      'steps',
      'item',
      'assigned_to',
      'cloturee_at',
      'progression',
    },
    references: {
      'item_id': 'item',
      'procedure_id': 'procedure',
    },
    // L'entretien rend l'article indisponible : son etat change.
    invalidates: {'item', 'stock_state'},
  );

  static const taskComment = EntityDescriptor(
    type: 'task_comment',
    label: 'Commentaire',
    collectionPath: _childCollection,
    priority: 40,
    // Un commentaire est un ajout immuable : jamais de conflit réel.
    conflictStrategy: ConflictStrategy.clientWins,
    serverOwnedFields: _commonServerFields,
    appendOnly: true,
  );

  static const stockMovement = EntityDescriptor(
    type: 'stock_movement',
    label: 'Mouvement de stock',
    collectionPath: ApiEndpoints.businessStockMovements,
    priority: 40,
    // Journal append-only : chaque mouvement est un fait, jamais réécrit. Le
    // serveur recalcule le stock à partir de la séquence qu'il reçoit.
    conflictStrategy: ConflictStrategy.clientWins,
    serverOwnedFields: _commonServerFields,
    references: {'item_id': 'item'},
    appendOnly: true,
    // Un mouvement change le stock disponible et l'etat de l'article.
    invalidates: {'stock_state', 'item'},
  );

  static const reservation = EntityDescriptor(
    type: 'reservation',
    label: 'Réservation',
    collectionPath: ApiEndpoints.businessReservations,
    itemPath: ApiEndpoints.businessReservation,
    priority: 30,
    // Une réservation engage une ressource partagée : deux appareils hors
    // ligne peuvent réserver le même article. Seul le serveur peut trancher,
    // et l'utilisateur doit être prévenu si sa demande est rejetée.
    conflictStrategy: ConflictStrategy.manual,
    serverOwnedFields: {
      ..._commonServerFields,
      'statut',
      'item',
      'demandeur',
      'quantite_retournee',
      'quantite_abimee',
      'quantite_perdue',
    },
    references: {'item_id': 'item'},
    // Reserver engage du stock : la disponibilite change.
    invalidates: {'stock_state', 'item'},
  );

  static const recurringTask = EntityDescriptor(
    type: 'recurring_task',
    label: 'Tâche récurrente',
    collectionPath: ApiEndpoints.businessRecurringTasks,
    itemPath: ApiEndpoints.businessRecurringTask,
    priority: 40,
    conflictStrategy: ConflictStrategy.mergeFields,
    serverOwnedFields: {
      ..._commonServerFields,
      'item',
      'category',
      'procedure',
      'derniere_execution',
    },
    references: {
      'item_id': 'item',
      'category_id': 'category',
      'procedure_id': 'procedure',
    },
  );

  static const reminder = EntityDescriptor(
    type: 'reminder',
    label: 'Rappel',
    collectionPath: ApiEndpoints.businessReminders,
    itemPath: ApiEndpoints.businessReminder,
    priority: 40,
    conflictStrategy: ConflictStrategy.clientWins,
    serverOwnedFields: {
      ..._commonServerFields,
      'envoye',
      'user',
      'task',
      'item',
    },
    references: {'task_id': 'maintenance_task', 'item_id': 'item'},
  );

  // ── Entités lues hors ligne mais écrites uniquement en ligne ─────────────

  static const member = EntityDescriptor(
    type: 'member',
    label: 'Membre',
    collectionPath: ApiEndpoints.businessMembers,
    itemPath: ApiEndpoints.businessMember,
    priority: 15,
    // Inviter envoie un e-mail et crée un compte : rien à simuler hors ligne.
    // Le serveur reste la seule autorité sur les rôles (RM-19).
    conflictStrategy: ConflictStrategy.serverWins,
    capability: OfflineCapability.readOnly,
  );

  static const role = EntityDescriptor(
    type: 'role',
    label: 'Rôle',
    collectionPath: ApiEndpoints.businessRoles,
    priority: 15,
    // Les permissions sont un objet de sécurité : jamais modifiées hors ligne.
    conflictStrategy: ConflictStrategy.serverWins,
    capability: OfflineCapability.readOnly,
  );

  static const alert = EntityDescriptor(
    type: 'alert',
    label: 'Alerte',
    collectionPath: ApiEndpoints.businessAlerts,
    priority: 60,
    conflictStrategy: ConflictStrategy.serverWins,
    capability: OfflineCapability.readOnly,
  );

  static const activity = EntityDescriptor(
    type: 'activity',
    label: 'Activité',
    collectionPath: ApiEndpoints.businessActivities,
    priority: 60,
    conflictStrategy: ConflictStrategy.serverWins,
    capability: OfflineCapability.readOnly,
  );

  static const stockState = EntityDescriptor(
    type: 'stock_state',
    label: 'État du stock',
    collectionPath: ApiEndpoints.businessStock,
    priority: 55,
    // Agrégat entièrement recalculé par le serveur.
    conflictStrategy: ConflictStrategy.serverWins,
    capability: OfflineCapability.readOnly,
  );

  static const dashboard = EntityDescriptor(
    type: 'dashboard',
    label: 'Tableau de bord',
    collectionPath: ApiEndpoints.businessDashboard,
    priority: 70,
    conflictStrategy: ConflictStrategy.serverWins,
    capability: OfflineCapability.readOnly,
  );

  /// Toutes les entités connues, indexées par type.
  static const Map<String, EntityDescriptor> all = {
    'category': category,
    'item': item,
    'procedure': procedure,
    'maintenance_task': maintenanceTask,
    'task_comment': taskComment,
    'stock_movement': stockMovement,
    'reservation': reservation,
    'recurring_task': recurringTask,
    'reminder': reminder,
    'member': member,
    'role': role,
    'alert': alert,
    'activity': activity,
    'stock_state': stockState,
    'dashboard': dashboard,
  };

  /// Entités rapatriées à chaque synchronisation descendante, dans l'ordre des
  /// dépendances (une catégorie avant les articles qui la citent).
  static const List<EntityDescriptor> pullOrder = [
    category,
    role,
    member,
    item,
    stockState,
    procedure,
    maintenanceTask,
    reservation,
    recurringTask,
    reminder,
    alert,
    activity,
  ];

  static EntityDescriptor? find(String type) => all[type];

  static EntityDescriptor require(String type) {
    final descriptor = all[type];
    if (descriptor == null) {
      throw ArgumentError("Type d'entité inconnu : $type");
    }
    return descriptor;
  }

  /// Les entités filles (commentaires, photos d'étape) vivent sous un parent :
  /// leur chemin est fourni explicitement à l'enfilement de l'opération.
  static String _childCollection(String businessId) => throw UnsupportedError(
        "Le chemin de cette entité dépend de son parent : il doit être passé "
        'explicitement à SyncQueue.enqueue().',
      );
}
