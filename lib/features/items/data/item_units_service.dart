import 'dart:convert';

import '../../../core/offline/db/local_store.dart';
import '../../../core/offline/entity_registry.dart';
import '../../../core/offline/offline_repository.dart';
import 'item_units.dart';

/// Résultat de la validation d'une unité saisie par l'utilisateur.
class UnitValidation {
  final bool valid;
  final String? error;

  /// Valeur nettoyée à enregistrer (espaces réduits, casse d'origine gardée).
  final String value;

  const UnitValidation.ok(this.value)
      : valid = true,
        error = null;

  const UnitValidation.invalid(this.error)
      : valid = false,
        value = '';
}

/// Les unités disponibles pour un business : la liste standard **plus celles
/// que l'équipe a créées**.
///
/// Une liste fermée ne peut pas couvrir tous les métiers servis par
/// l'application. Plutôt que d'imposer un choix ou de retomber sur du texte
/// libre non structuré, l'utilisateur ajoute sa propre unité : elle est
/// enregistrée, réapparaît dans la liste aux créations suivantes, et devient
/// donc réutilisable par toute l'équipe sur cet appareil.
///
/// Deux sources alimentent les unités personnalisées :
///
/// * celles explicitement ajoutées par l'utilisateur, persistées en base ;
/// * celles déjà portées par des articles du catalogue local — sans quoi une
///   unité créée sur un autre appareil, ou avant cette fonctionnalité,
///   n'apparaîtrait jamais dans la liste.
class ItemUnitsService {
  final OfflineRepository _offline;

  ItemUnitsService(this._offline);

  static String _key(String businessId) => 'units.custom.$businessId';

  /// Unités personnalisées connues pour ce business, triées alphabétiquement.
  Future<List<String>> customUnits(String businessId) async {
    final enregistrees = await _persisted(businessId);

    // Les unités portées par les articles déjà en base : elles existent
    // réellement dans le catalogue, elles doivent donc être proposables.
    final items = await _offline.store.listPayloads(
      EntityRegistry.item.type,
      businessId: businessId,
    );
    final utilisees = <String>[];
    for (final row in items) {
      final unite = (row['unite'] as String?)?.trim();
      if (unite == null || unite.isEmpty) continue;
      if (ItemUnits.normalize(unite) != null) continue; // déjà standard
      utilisees.add(unite);
    }

    return _dedupe([...enregistrees, ...utilisees]);
  }

  /// Mémorise une unité personnalisée pour ce business.
  ///
  /// Sans effet si l'unité correspond déjà à une entrée standard : la liste
  /// personnalisée ne doit pas se remplir de doublons de `kg` ou `pièce`.
  Future<void> remember(String businessId, String unit) async {
    final validation = validate(unit);
    if (!validation.valid) return;
    if (ItemUnits.normalize(validation.value) != null) return;

    final existantes = await _persisted(businessId);
    if (_containsIgnoringCase(existantes, validation.value)) return;

    final maj = _dedupe([...existantes, validation.value]);
    await _offline.store.setMeta(_key(businessId), jsonEncode(maj));
  }

  /// Retire une unité de la liste personnalisée.
  ///
  /// Les articles qui l'utilisent déjà **ne sont pas modifiés** : leur unité
  /// reste ce qu'elle est. Elle disparaît seulement des propositions — et
  /// réapparaîtra tant qu'un article la porte, puisque le catalogue local est
  /// l'une des deux sources.
  Future<void> forget(String businessId, String unit) async {
    final existantes = await _persisted(businessId);
    final restantes = existantes
        .where((u) => u.toLowerCase() != unit.trim().toLowerCase())
        .toList();
    await _offline.store.setMeta(_key(businessId), jsonEncode(restantes));
  }

  /// Vérifie qu'une unité saisie est acceptable avant de l'enregistrer.
  ///
  /// La limite de longueur n'est pas décorative : `Item.unite` est un
  /// `CharField(max_length=30)`. Laisser passer plus long ferait échouer la
  /// création côté serveur, et l'opération partirait en erreur de
  /// synchronisation bien après que l'utilisateur a quitté l'écran.
  static UnitValidation validate(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) {
      return const UnitValidation.invalid('Saisissez une unité.');
    }
    if (value.length > ItemUnits.maxLength) {
      return UnitValidation.invalid(
        'Une unité ne peut pas dépasser ${ItemUnits.maxLength} caractères.',
      );
    }
    // Une unité purement numérique est presque sûrement une quantité saisie
    // dans le mauvais champ.
    if (RegExp(r'^[0-9]+$').hasMatch(value)) {
      return const UnitValidation.invalid(
        "Une unité ne peut pas être un nombre seul (exemple : « sac », « kg »).",
      );
    }
    return UnitValidation.ok(value);
  }

  Future<List<String>> _persisted(String businessId) async {
    final raw = await _offline.store.meta(_key(businessId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    } catch (_) {
      // Entrée corrompue : on repart d'une liste vide plutôt que de casser
      // l'écran de création.
      return const [];
    }
  }

  /// Déduplique en ignorant la casse, en gardant la première graphie vue.
  static List<String> _dedupe(List<String> units) {
    final vues = <String>{};
    final resultat = <String>[];
    for (final unit in units) {
      final propre = unit.trim();
      if (propre.isEmpty) continue;
      if (!vues.add(propre.toLowerCase())) continue;
      resultat.add(propre);
    }
    resultat.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return resultat;
  }

  static bool _containsIgnoringCase(List<String> units, String value) =>
      units.any((u) => u.toLowerCase() == value.toLowerCase());
}

/// Portée de stockage, exposée pour les tests.
String unitsScopeOf(String? businessId) => LocalStore.scopeOf(businessId);
