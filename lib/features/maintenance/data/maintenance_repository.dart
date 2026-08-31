import 'dart:io';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/offline/derived_cache.dart';
import '../../../core/offline/entity_registry.dart';
import '../../../core/offline/offline_repository.dart';
import '../../../features/items/data/models/item.dart';
import 'models/maintenance_task.dart';
import 'models/procedure.dart';
import 'models/recurring_task.dart';
import 'models/reminder.dart';

/// Entretien : tâches, procédures, récurrences et rappels, en Offline-First.
///
/// L'entretien est le cas d'usage le plus exposé au terrain — atelier, cave,
/// dépôt — donc celui où l'absence de réseau est la règle plutôt que
/// l'exception. Tout le CRUD y fonctionne hors ligne ; seules les statistiques
/// agrégées, calculées par le serveur, restent servies depuis leur dernière
/// copie connue.
class MaintenanceRepository {
  final ApiClient _api;
  final OfflineRepository _offline;
  final DerivedCache _derived;

  MaintenanceRepository(this._api, this._offline, this._derived);

  // ── Tâches ───────────────────────────────────────────────────────────────

  Future<List<MaintenanceTaskModel>> tasks(String businessId,
      {bool refresh = false}) async {
    final rows = await _offline.readCollection(
      EntityRegistry.maintenanceTask,
      businessId,
      refresh: refresh,
    );
    return rows.map(MaintenanceTaskModel.fromJson).toList();
  }

  Future<MaintenanceTaskModel> taskDetail(
    String businessId,
    String taskId, {
    bool refresh = false,
  }) async {
    final payload = await _offline.readOne(
      EntityRegistry.maintenanceTask,
      businessId,
      taskId,
      refresh: refresh,
    );
    if (payload == null) {
      throw ApiException(404, 'Tâche introuvable.');
    }
    return MaintenanceTaskModel.fromJson(payload);
  }

  Future<MaintenanceTaskModel> createTask(
    String businessId, {
    required String itemId,
    String? procedureId,
    String? motif,
    String? assignedToId,
    double? coutMainOeuvre,
    double? coutMateriel,
  }) async {
    final resolvedItem = await _offline.idMap.resolve(itemId);
    final item = await _offline.store.findPayload(
      EntityRegistry.item.type,
      resolvedItem,
    );
    final procedure = procedureId == null
        ? null
        : await _offline.store.findPayload(
            EntityRegistry.procedure.type,
            await _offline.idMap.resolve(procedureId),
          );

    final payload = await _offline.create(
      EntityRegistry.maintenanceTask,
      businessId,
      {
        'item_id': resolvedItem,
        if (procedureId != null && procedureId.isNotEmpty)
          'procedure_id': procedureId,
        if (motif != null && motif.isNotEmpty) 'motif': motif,
        'assigned_to_id': ?assignedToId,
        'cout_main_oeuvre': ?coutMainOeuvre,
        'cout_materiel': ?coutMateriel,
      },
      // Une tâche créée hors ligne doit s'afficher comme une vraie tâche :
      // avec son article, sa procédure et ses étapes, pas une coquille vide.
      optimisticFields: {
        'statut': 'A_FAIRE',
        'item': ?item,
        'procedure': ?procedure,
        'steps': _stepsFromProcedure(procedure),
      },
    );
    return MaintenanceTaskModel.fromJson(payload);
  }

  Future<MaintenanceTaskModel> updateTask(
    String businessId,
    String taskId, {
    String? assignedToId,
    double? coutMainOeuvre,
    double? coutMateriel,
  }) async {
    final payload = await _offline.update(
      EntityRegistry.maintenanceTask,
      businessId,
      taskId,
      {
        'assigned_to_id': ?assignedToId,
        'cout_main_oeuvre': ?coutMainOeuvre,
        'cout_materiel': ?coutMateriel,
      },
    );
    return MaintenanceTaskModel.fromJson(payload);
  }

  /// Avance une étape (EN_COURS puis TERMINE).
  ///
  /// L'étape est mise à jour localement tout de suite : un technicien qui coche
  /// ses étapes dans un sous-sol doit voir sa progression, pas un écran figé.
  Future<void> updateStep(
    String businessId,
    String taskId,
    String stepId, {
    required String statut,
  }) async {
    final resolvedTask = await _offline.idMap.resolve(taskId);
    await _offline.action(
      EntityRegistry.maintenanceTask,
      businessId,
      resolvedTask,
      path: ApiEndpoints.businessMaintenanceTaskStep(
        businessId,
        resolvedTask,
        stepId,
      ),
      body: {'statut': statut},
      // TaskStepUpdateView n'expose que PATCH.
      method: 'PATCH',
      localEffect: (current) => _withStepStatus(current, stepId, statut),
    );
  }

  /// Clôture une tâche (entretien.manage, RM-11).
  Future<MaintenanceTaskModel> clotureTask(
    String businessId,
    String taskId, {
    bool partielle = false,
  }) async {
    final resolvedTask = await _offline.idMap.resolve(taskId);
    final payload = await _offline.action(
      EntityRegistry.maintenanceTask,
      businessId,
      resolvedTask,
      path: ApiEndpoints.businessMaintenanceTaskCloture(
        businessId,
        resolvedTask,
      ),
      body: {'partielle': partielle},
      localEffect: (current) => {
        ...current,
        'statut': partielle ? 'PARTIEL' : 'TERMINE',
        'cloturee_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (payload == null) {
      throw ApiException(404, 'Tâche introuvable.');
    }
    return MaintenanceTaskModel.fromJson(payload);
  }

  // ── Procédures ───────────────────────────────────────────────────────────

  Future<List<ProcedureModel>> procedures(String businessId,
      {bool refresh = false}) async {
    final rows = await _offline.readCollection(
      EntityRegistry.procedure,
      businessId,
      refresh: refresh,
    );
    return rows.map(ProcedureModel.fromJson).toList();
  }

  Future<ProcedureModel> procedureDetail(
    String businessId,
    String procedureId, {
    bool refresh = false,
  }) async {
    final payload = await _offline.readOne(
      EntityRegistry.procedure,
      businessId,
      procedureId,
      refresh: refresh,
    );
    if (payload == null) {
      throw ApiException(404, 'Procédure introuvable.');
    }
    return ProcedureModel.fromJson(payload);
  }

  Future<ProcedureModel> createProcedure(
    String businessId, {
    required String nom,
    String description = '',
    required List<Map<String, dynamic>> steps,
  }) async {
    final payload = await _offline.create(
      EntityRegistry.procedure,
      businessId,
      {
        'nom': nom,
        'description': description,
        'steps_input': steps,
      },
      // `steps_input` est la forme attendue en écriture, `steps` celle renvoyée
      // en lecture : on fabrique la seconde pour que l'affichage fonctionne
      // avant le premier aller-retour.
      optimisticFields: {
        'est_actif': true,
        'steps': _normalizeSteps(steps),
      },
    );
    return ProcedureModel.fromJson(payload);
  }

  Future<ProcedureModel> updateProcedure(
    String businessId,
    String procedureId, {
    String? nom,
    String? description,
    bool? estActif,
    List<Map<String, dynamic>>? steps,
  }) async {
    final changes = <String, dynamic>{
      'nom': ?nom,
      'description': ?description,
      'est_actif': ?estActif,
      'steps_input': ?steps,
    };

    final payload = await _offline.update(
      EntityRegistry.procedure,
      businessId,
      procedureId,
      changes,
    );
    if (steps == null) return ProcedureModel.fromJson(payload);

    // Même raison qu'à la création : refléter localement la forme de lecture.
    return ProcedureModel.fromJson({
      ...payload,
      'steps': _normalizeSteps(steps),
    });
  }

  Future<void> deleteProcedure(String businessId, String procedureId) =>
      _offline.delete(EntityRegistry.procedure, businessId, procedureId);

  // ── Commentaires ─────────────────────────────────────────────────────────

  Future<List<TaskCommentModel>> taskComments(
    String businessId,
    String taskId, {
    bool refresh = false,
  }) async {
    final resolvedTask = await _offline.idMap.resolve(taskId);
    final rows = await _offline.readCollection(
      EntityRegistry.taskComment,
      businessId,
      path: '${ApiEndpoints.businessMaintenanceTask(businessId, resolvedTask)}'
          'comments/',
      refresh: refresh,
    );
    return rows
        .where((row) => row['task_id'] == null || row['task_id'] == resolvedTask)
        .map(TaskCommentModel.fromJson)
        .toList();
  }

  Future<TaskCommentModel> addComment(
    String businessId,
    String taskId, {
    required String contenu,
  }) async {
    final resolvedTask = await _offline.idMap.resolve(taskId);
    final payload = await _offline.create(
      EntityRegistry.taskComment,
      businessId,
      {'contenu': contenu},
      path: '${ApiEndpoints.businessMaintenanceTask(businessId, resolvedTask)}'
          'comments/',
      optimisticFields: {'task_id': resolvedTask},
    );
    return TaskCommentModel.fromJson(payload);
  }

  Future<void> deleteComment(
    String businessId,
    String taskId,
    String commentId,
  ) async {
    final resolvedTask = await _offline.idMap.resolve(taskId);
    await _offline.delete(
      EntityRegistry.taskComment,
      businessId,
      commentId,
      path: '${ApiEndpoints.businessMaintenanceTask(businessId, resolvedTask)}'
          'comments/$commentId/',
    );
  }

  // ── Photos d'étape ───────────────────────────────────────────────────────

  /// Envoie une photo d'étape (AVANT / APRÈS).
  ///
  /// L'envoi est mis en file et le fichier reste sur le téléphone : c'est le
  /// scénario type du technicien qui documente une intervention sans réseau.
  Future<void> uploadStepPhoto(
    String businessId,
    String taskId,
    String stepId, {
    required File image,
    required String type,
    String? caption,
  }) async {
    final resolvedTask = await _offline.idMap.resolve(taskId);
    await _offline.upload(
      EntityRegistry.maintenanceTask,
      businessId,
      resolvedTask,
      path: '${ApiEndpoints.businessMaintenanceTaskStep(businessId, resolvedTask, stepId)}'
          'photos/',
      filePath: image.path,
      field: 'image',
      fields: {
        'type': type,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      },
    );
  }

  Future<void> deleteStepPhoto(
    String businessId,
    String taskId,
    String stepId,
    String photoId,
  ) async {
    final resolvedTask = await _offline.idMap.resolve(taskId);
    await _offline.action(
      EntityRegistry.maintenanceTask,
      businessId,
      resolvedTask,
      path: '${ApiEndpoints.businessMaintenanceTaskStep(businessId, resolvedTask, stepId)}'
          'photos/$photoId/',
      // TaskStepPhotoDeleteView n'expose que DELETE.
      method: 'DELETE',
    );
  }

  // ── Tâches récurrentes ───────────────────────────────────────────────────

  Future<List<RecurringTaskModel>> recurringTasks(String businessId,
      {bool refresh = false}) async {
    final rows = await _offline.readCollection(
      EntityRegistry.recurringTask,
      businessId,
      refresh: refresh,
    );
    return rows.map(RecurringTaskModel.fromJson).toList();
  }

  Future<RecurringTaskModel> createRecurringTask(
    String businessId, {
    String? itemId,
    String? categoryId,
    required String procedureId,
    required int frequenceJours,
    required String prochaineExecution,
    bool estActif = true,
  }) async {
    final payload = await _offline.create(
      EntityRegistry.recurringTask,
      businessId,
      {
        'item_id': ?itemId,
        'category_id': ?categoryId,
        'procedure_id': procedureId,
        'frequence_jours': frequenceJours,
        'prochaine_execution': prochaineExecution,
        'est_actif': estActif,
      },
    );
    return RecurringTaskModel.fromJson(payload);
  }

  Future<RecurringTaskModel> updateRecurringTask(
    String businessId,
    String recurringId, {
    int? frequenceJours,
    String? prochaineExecution,
    bool? estActif,
  }) async {
    final payload = await _offline.update(
      EntityRegistry.recurringTask,
      businessId,
      recurringId,
      {
        'frequence_jours': ?frequenceJours,
        'prochaine_execution': ?prochaineExecution,
        'est_actif': ?estActif,
      },
    );
    return RecurringTaskModel.fromJson(payload);
  }

  Future<void> deleteRecurringTask(String businessId, String recurringId) =>
      _offline.delete(EntityRegistry.recurringTask, businessId, recurringId);

  // ── Rappels ──────────────────────────────────────────────────────────────

  Future<List<ReminderModel>> reminders(
    String businessId, {
    bool? mesRappels,
    bool refresh = false,
  }) async {
    final rows = await _offline.readCollection(
      EntityRegistry.reminder,
      businessId,
      refresh: refresh,
    );
    final reminders = rows.map(ReminderModel.fromJson).toList();
    // Le filtre `mes_rappels` était appliqué par le serveur via un paramètre
    // d'URL. En local-first, on filtre après lecture pour que la liste reste
    // disponible hors ligne quel que soit le filtre choisi.
    return reminders;
  }

  Future<ReminderModel> createReminder(
    String businessId, {
    String? taskId,
    String? itemId,
    required String userId,
    required String rappelA,
    required String message,
  }) async {
    final payload = await _offline.create(
      EntityRegistry.reminder,
      businessId,
      {
        'task_id': ?taskId,
        'item_id': ?itemId,
        'user_id': userId,
        'rappel_a': rappelA,
        'message': message,
      },
      optimisticFields: const {'envoye': false},
    );
    return ReminderModel.fromJson(payload);
  }

  Future<void> deleteReminder(String businessId, String reminderId) =>
      _offline.delete(EntityRegistry.reminder, businessId, reminderId);

  // ── Lectures dérivées (calculées par le serveur) ─────────────────────────

  /// Historique global avec filtres.
  ///
  /// Agrégat serveur : hors ligne, la dernière copie connue est renvoyée. Les
  /// filtres portent alors sur cette copie plutôt que sur la base complète —
  /// une limitation assumée, l'alternative étant un écran vide.
  Future<List<Map<String, dynamic>>> history(
    String businessId, {
    String? type,
    String? itemId,
    String? acteurId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String>[
      if (type != null) 'type=$type',
      if (itemId != null) 'item_id=$itemId',
      if (acteurId != null) 'acteur_id=$acteurId',
      if (dateFrom != null) 'date_from=$dateFrom',
      if (dateTo != null) 'date_to=$dateTo',
    ];
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return _derived.list(
      'history.$businessId$query',
      '${ApiEndpoints.businessHistory(businessId)}$query',
    );
  }

  /// Statistiques avancées (calculées par le serveur).
  Future<Map<String, dynamic>> analytics(String businessId) async {
    return _derived.object(
      'analytics.$businessId',
      ApiEndpoints.businessAnalytics(businessId),
    );
  }

  /// Articles disponibles pour le formulaire de tâche.
  Future<List<ItemModel>> items(String businessId,
      {bool refresh = false}) async {
    final rows = await _offline.readCollection(
      EntityRegistry.item,
      businessId,
      refresh: refresh,
    );
    return rows.map(ItemModel.fromJson).toList();
  }

  /// Retrouve un article par son QR code.
  ///
  /// Cherché d'abord dans la base locale : scanner un article dans un dépôt
  /// sans réseau est précisément le cas d'usage du QR code.
  Future<ItemModel> scanItem(String businessId, String qrCode) async {
    final local = await _offline.store.listPayloads(
      EntityRegistry.item.type,
      businessId: businessId,
    );
    for (final row in local) {
      if (row['qr_code'] == qrCode) return ItemModel.fromJson(row);
    }

    if (_offline.connectivity.isOffline) {
      throw const OfflineUnsupportedException(
        'Cet article n\'est pas encore dans les données téléchargées sur cet '
        'appareil. Reconnectez-vous pour le retrouver.',
      );
    }

    final data = await _api.get(
      ApiEndpoints.businessItemScan(businessId, qrCode),
    ) as Map<String, dynamic>;
    return ItemModel.fromJson(data);
  }

  // ── Aides locales ────────────────────────────────────────────────────────

  /// Étapes d'une tâche fabriquées depuis sa procédure, pour l'affichage
  /// immédiat d'une tâche créée hors ligne.
  static List<Map<String, dynamic>> _stepsFromProcedure(
    Map<String, dynamic>? procedure,
  ) {
    final steps = procedure?['steps'];
    if (steps is! List) return const [];
    return steps.whereType<Map<String, dynamic>>().map((step) {
      return {
        'id': step['id'],
        'nom': step['nom'],
        'ordre': step['ordre'],
        'obligatoire': step['obligatoire'],
        'type': step['type'],
        'description': step['description'],
        'statut': 'A_FAIRE',
      };
    }).toList();
  }

  static Map<String, dynamic> _withStepStatus(
    Map<String, dynamic> task,
    String stepId,
    String statut,
  ) {
    final steps = task['steps'];
    if (steps is! List) return task;

    final updated = steps.map((step) {
      if (step is! Map) return step;
      if (step['id'] != stepId) return step;
      return {...step.cast<String, dynamic>(), 'statut': statut};
    }).toList();

    final allDone = updated.every(
      (step) => step is Map && step['statut'] == 'TERMINE',
    );
    return {
      ...task,
      'steps': updated,
      'statut': allDone ? 'TERMINE' : 'EN_COURS',
    };
  }

  static List<Map<String, dynamic>> _normalizeSteps(
    List<Map<String, dynamic>> steps,
  ) {
    var index = 0;
    return steps.map((step) {
      index++;
      return {
        'id': step['id'] ?? 'local-step-$index',
        'ordre': step['ordre'] ?? index,
        ...step,
      };
    }).toList();
  }
}
