import '../db/local_record.dart';
import '../entity_registry.dart';

/// Ce que le moteur doit faire d'un enregistrement après arbitrage.
enum ConflictOutcome {
  /// Écrire la version résolue en local et considérer l'entité à jour.
  takeResolved,

  /// Conserver la version locale et la renvoyer au serveur.
  pushLocal,

  /// Marquer l'entité en conflit et demander un arbitrage à l'utilisateur.
  askUser,
}

class ConflictResolution {
  final ConflictOutcome outcome;
  final Map<String, dynamic> payload;
  final String reason;

  const ConflictResolution(this.outcome, this.payload, {this.reason = ''});
}

/// Arbitre les divergences entre la version locale et la version serveur.
///
/// Il n'y a pas de stratégie universelle : appliquer « le serveur gagne »
/// partout ferait perdre du travail hors ligne, et « le client gagne » partout
/// écraserait les décisions des autres membres de l'équipe. La stratégie est
/// donc portée par [EntityDescriptor.conflictStrategy], entité par entité.
class ConflictResolver {
  const ConflictResolver();

  /// Arbitre entre [local] (modifié hors ligne) et [server] (version fraîche).
  ConflictResolution resolve({
    required EntityDescriptor descriptor,
    required LocalRecord local,
    required Map<String, dynamic> server,
  }) {
    switch (descriptor.conflictStrategy) {
      case ConflictStrategy.serverWins:
        return ConflictResolution(
          ConflictOutcome.takeResolved,
          server,
          reason: 'Version du serveur retenue (${descriptor.label}).',
        );

      case ConflictStrategy.clientWins:
        return ConflictResolution(
          ConflictOutcome.pushLocal,
          local.payload,
          reason: 'Version locale retenue (${descriptor.label}).',
        );

      case ConflictStrategy.lastWriteWins:
        final serverStamp = _stamp(server);
        final localStamp = local.localUpdatedAt;
        if (serverStamp != null && serverStamp.isAfter(localStamp)) {
          return ConflictResolution(
            ConflictOutcome.takeResolved,
            server,
            reason: 'Le serveur a une version plus récente.',
          );
        }
        return ConflictResolution(
          ConflictOutcome.pushLocal,
          local.payload,
          reason: 'La modification locale est la plus récente.',
        );

      case ConflictStrategy.mergeFields:
        return _merge(descriptor, local, server);

      case ConflictStrategy.manual:
        // Si le serveur n'a en fait rien changé depuis la copie de référence,
        // il n'y a pas de vrai conflit : inutile de déranger l'utilisateur.
        if (!_serverChanged(local, server)) {
          return ConflictResolution(
            ConflictOutcome.pushLocal,
            local.payload,
            reason: 'Aucune modification concurrente côté serveur.',
          );
        }
        return ConflictResolution(
          ConflictOutcome.askUser,
          server,
          reason:
              '${descriptor.label} modifiée des deux côtés : votre arbitrage '
              'est nécessaire.',
        );
    }
  }

  /// Fusion trois voies, champ par champ.
  ///
  /// Le principe : ne réécrire que ce que l'utilisateur a **effectivement**
  /// touché hors ligne. Un champ que le serveur a changé et que le local n'a
  /// pas modifié garde la valeur serveur ; un champ modifié localement garde
  /// la valeur locale. Sans la copie de référence ([LocalRecord.basePayload]),
  /// on ne saurait pas faire la différence et on écraserait tout.
  ConflictResolution _merge(
    EntityDescriptor descriptor,
    LocalRecord local,
    Map<String, dynamic> server,
  ) {
    final base = local.basePayload;
    if (base == null) {
      // Aucune référence : on ne peut pas fusionner honnêtement. Le serveur
      // fait foi, sauf pour les champs absents de sa réponse.
      return ConflictResolution(
        ConflictOutcome.takeResolved,
        {...server},
        reason: 'Aucune version de référence : version serveur retenue.',
      );
    }

    final merged = <String, dynamic>{...server};
    final changed = <String>[];

    for (final entry in local.payload.entries) {
      final key = entry.key;
      if (descriptor.serverOwnedFields.contains(key)) continue;

      final localValue = entry.value;
      final baseValue = base[key];
      if (_equal(localValue, baseValue)) continue; // pas touché en local

      merged[key] = localValue;
      changed.add(key);
    }

    if (changed.isEmpty) {
      return ConflictResolution(
        ConflictOutcome.takeResolved,
        server,
        reason: 'Aucune modification locale à conserver.',
      );
    }

    return ConflictResolution(
      ConflictOutcome.pushLocal,
      merged,
      reason: 'Champs conservés depuis cet appareil : ${changed.join(', ')}.',
    );
  }

  /// Champs réellement modifiés en local depuis la dernière version serveur.
  ///
  /// C'est ce qui part dans un PATCH : envoyer l'objet entier réécrirait des
  /// champs que l'utilisateur n'a jamais touchés, et écraserait au passage le
  /// travail des autres membres de l'équipe.
  Map<String, dynamic> localChanges({
    required EntityDescriptor descriptor,
    required LocalRecord record,
  }) {
    final base = record.basePayload;
    final changes = <String, dynamic>{};

    record.payload.forEach((key, value) {
      if (descriptor.serverOwnedFields.contains(key)) return;
      if (base != null && _equal(base[key], value)) return;
      changes[key] = value;
    });
    return changes;
  }

  bool _serverChanged(LocalRecord local, Map<String, dynamic> server) {
    final base = local.basePayload;
    if (base == null) return true;
    final serverStamp = _stamp(server);
    final baseStamp = _stamp(base);
    if (serverStamp != null && baseStamp != null) {
      return serverStamp.isAfter(baseStamp);
    }
    return !_equal(base, server);
  }

  DateTime? _stamp(Map<String, dynamic> payload) {
    final raw = payload['updated_at'] ?? payload['created_at'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Égalité structurelle, suffisante pour du JSON décodé.
  static bool _equal(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_equal(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_equal(a[i], b[i])) return false;
      }
      return true;
    }
    // Le JSON DRF renvoie parfois les décimaux sous forme de chaîne
    // ("12.00") : comparer les représentations évite un faux conflit.
    if (a is num && b is String) return a.toString() == b;
    if (a is String && b is num) return b.toString() == a;
    return a == b;
  }
}
