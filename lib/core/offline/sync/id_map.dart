import 'package:sqflite/sqflite.dart';

import '../db/local_database.dart';

/// Correspondance identifiant local temporaire → identifiant serveur.
///
/// Quand une entité est créée hors ligne, l'application lui attribue un
/// identifiant local (`local:<uuid>`) pour que l'interface, les écrans de
/// détail et les entités filles puissent la référencer immédiatement. Le
/// serveur attribue le sien à la synchronisation.
///
/// Cette table est **persistée volontairement** : un écran ouvert avant la
/// synchronisation, une notification push, ou une opération encore en file
/// peuvent continuer à citer l'ancien identifiant longtemps après. Les jeter
/// après le remplacement produirait des « article introuvable » aléatoires.
class IdMap {
  final LocalDatabase _database;

  /// Petit cache mémoire : la résolution est appelée à chaque opération
  /// poussée, inutile de retourner en base à chaque fois.
  final Map<String, String> _cache = {};

  IdMap(this._database);

  DatabaseExecutor _exec(Transaction? txn) => txn ?? _database.db;

  /// Enregistre la correspondance attribuée par le serveur.
  Future<void> record(
    String entityType,
    String localId,
    String serverId, {
    Transaction? txn,
  }) async {
    _cache[localId] = serverId;
    await _exec(txn).insert(
      'id_map',
      {
        'local_id': localId,
        'server_id': serverId,
        'entity_type': entityType,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Identifiant serveur correspondant, ou null si la création n'a pas encore
  /// été acceptée.
  Future<String?> serverIdFor(String localId, {Transaction? txn}) async {
    final cached = _cache[localId];
    if (cached != null) return cached;

    final rows = await _exec(txn).query(
      'id_map',
      columns: ['server_id'],
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final serverId = rows.first['server_id'] as String;
    _cache[localId] = serverId;
    return serverId;
  }

  /// Résout un identifiant quel qu'il soit : renvoie l'identifiant serveur
  /// s'il est connu, sinon l'identifiant reçu tel quel.
  Future<String> resolve(String id, {Transaction? txn}) async =>
      await serverIdFor(id, txn: txn) ?? id;

  Future<void> clear({Transaction? txn}) async {
    _cache.clear();
    await _exec(txn).delete('id_map');
  }
}
