import 'dart:async';

import 'package:sqflite/sqflite.dart';

/// Base de données locale persistante (SQLite) — socle de l'architecture
/// Offline-First.
///
/// Pourquoi SQLite et pas un simple cache clé/valeur : le moteur de
/// synchronisation doit pouvoir écrire *atomiquement* un enregistrement métier
/// **et** l'opération de synchronisation correspondante. Sans transaction, une
/// application tuée entre les deux écritures perdrait soit la donnée, soit
/// l'ordre de l'envoyer — exactement ce que l'architecture doit interdire.
///
/// Schéma (v1) :
/// * `records`     — documents JSON métier, un par entité, avec leur état de
///                   synchronisation et leur copie serveur de référence ;
/// * `sync_ops`    — file d'attente persistante des opérations à pousser ;
/// * `id_map`      — correspondance identifiant local temporaire → identifiant
///                   serveur, conservée après la synchronisation ;
/// * `sync_meta`   — curseurs et métadonnées de synchronisation ;
/// * `sync_conflicts` — conflits nécessitant un arbitrage utilisateur.
class LocalDatabase {
  static const String fileName = 'dodome_offline.db';
  static const int schemaVersion = 1;

  /// Nom du fichier de base.
  ///
  /// Surchargeable pour que deux suites de tests puissent tourner en parallèle
  /// sans se partager le même fichier — sans quoi elles s'effacent mutuellement
  /// leurs données et échouent de façon erratique.
  final String name;

  LocalDatabase({String? fileName}) : name = fileName ?? LocalDatabase.fileName;

  Database? _db;

  /// Ouvre (et crée au besoin) la base. Idempotent.
  Future<Database> open() async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final path = '${await getDatabasesPath()}/$name';
    final db = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        // Les suppressions en cascade et l'intégrité référentielle ne sont
        // utiles que si les clés étrangères sont actives (désactivées par
        // défaut dans SQLite).
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, from, to) async => _migrate(db, from, to),
    );
    _db = db;
    return db;
  }

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError(
        'LocalDatabase.open() doit être appelé avant tout accès.',
      );
    }
    return database;
  }

  bool get isOpen => _db?.isOpen ?? false;

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      db.transaction(action);

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Efface toutes les données locales (déconnexion, changement de compte).
  ///
  /// Volontairement destructif : à n'appeler qu'après avoir vérifié qu'aucune
  /// opération n'est en attente, sinon le travail hors ligne serait perdu.
  Future<void> wipe() async {
    await db.transaction((txn) async {
      for (final table in const [
        'records',
        'sync_ops',
        'id_map',
        'sync_meta',
        'sync_conflicts',
      ]) {
        await txn.delete(table);
      }
    });
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE records (
        entity_type       TEXT NOT NULL,
        id                TEXT NOT NULL,
        scope             TEXT NOT NULL,
        payload           TEXT NOT NULL,
        base_payload      TEXT,
        local_updated_at  TEXT NOT NULL,
        server_updated_at TEXT,
        sync_state        TEXT NOT NULL,
        deleted           INTEGER NOT NULL DEFAULT 0,
        local_only        INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (entity_type, id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_records_scope '
      'ON records (entity_type, scope, deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_records_dirty ON records (sync_state)',
    );

    // `seq` est la clé d'ordre : il matérialise l'ordre d'enfilement, donc
    // l'ordre causal des actions de l'utilisateur.
    await db.execute('''
      CREATE TABLE sync_ops (
        seq              INTEGER PRIMARY KEY AUTOINCREMENT,
        id               TEXT NOT NULL UNIQUE,
        scope            TEXT NOT NULL,
        entity_type      TEXT NOT NULL,
        entity_id        TEXT NOT NULL,
        op_type          TEXT NOT NULL,
        method           TEXT NOT NULL,
        endpoint         TEXT NOT NULL,
        payload          TEXT,
        file_path        TEXT,
        file_field       TEXT,
        file_fields      TEXT,
        status           TEXT NOT NULL,
        retry_count      INTEGER NOT NULL DEFAULT 0,
        next_attempt_at  TEXT,
        last_error       TEXT,
        priority         INTEGER NOT NULL DEFAULT 100,
        idempotency_key  TEXT NOT NULL,
        depends_on       TEXT,
        created_at       TEXT NOT NULL,
        updated_at       TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_ops_pending ON sync_ops (status, priority, seq)',
    );
    await db.execute(
      'CREATE INDEX idx_ops_entity ON sync_ops (entity_type, entity_id, status)',
    );

    await db.execute('''
      CREATE TABLE id_map (
        local_id    TEXT PRIMARY KEY,
        server_id   TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        created_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_conflicts (
        id             TEXT PRIMARY KEY,
        scope          TEXT NOT NULL,
        entity_type    TEXT NOT NULL,
        entity_id      TEXT NOT NULL,
        local_payload  TEXT NOT NULL,
        server_payload TEXT,
        reason         TEXT NOT NULL,
        detected_at    TEXT NOT NULL,
        resolved       INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_conflicts_open ON sync_conflicts (scope, resolved)',
    );
  }

  /// Migrations de schéma.
  ///
  /// Règle absolue : une migration ne doit **jamais** supprimer `sync_ops` ni
  /// les `records` non synchronisés — une mise à jour de l'application ne peut
  /// pas faire perdre le travail hors ligne de l'utilisateur.
  static Future<void> _migrate(Database db, int from, int to) async {
    // v1 : schéma initial, rien à migrer pour l'instant.
  }
}
