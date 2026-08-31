/// Unités de mesure d'un article.
///
/// **Ce que l'unité veut dire** : elle répond à la question « la quantité en
/// stock compte quoi ? ». `25` + `kg` se lit « 25 kilogrammes » ; `24` +
/// `bouteille` se lit « 24 bouteilles ». Sans elle, un chiffre de stock est
/// ambigu — 12 de riz, c'est 12 sacs ou 12 kilos ?
///
/// **Pourquoi une liste plutôt qu'un champ libre** : en saisie libre, la même
/// unité s'écrit `kg`, `Kg`, `kilo`, `kilogramme`. Les totaux et les filtres
/// deviennent faux, et deux membres de l'équipe ne saisissent jamais pareil.
///
/// **Pourquoi la saisie libre reste possible** : l'application sert plusieurs
/// métiers (événementiel, restauration, location de matériel). Aucune liste
/// fermée ne peut les couvrir tous, et bloquer un utilisateur sur une unité
/// manquante serait pire que l'incohérence qu'on cherche à éviter. La liste
/// couvre les cas courants, « Autre » couvre le reste.
///
/// Le backend stocke `unite` en texte libre (`CharField(max_length=30)`) :
/// aucune migration n'est nécessaire, et les articles déjà saisis restent
/// valides même si leur unité n'est pas dans la liste.
library;

/// Une unité proposée à la sélection.
class ItemUnit {
  /// Valeur envoyée au serveur et stockée. Volontairement courte et stable :
  /// c'est elle qui sert de clé, pas le libellé affiché.
  final String value;

  /// Libellé affiché dans la liste déroulante.
  final String label;

  /// Regroupement, pour que la liste reste lisible quand elle s'allonge.
  final String group;

  const ItemUnit(this.value, this.label, this.group);
}

class ItemUnits {
  ItemUnits._();

  /// Longueur maximale acceptée par le backend (`Item.unite`).
  static const int maxLength = 30;

  /// Unité par défaut d'un article dénombrable — le cas le plus fréquent.
  static const String defaultValue = 'pièce';

  static const List<ItemUnit> all = [
    // ── Comptage à l'unité ────────────────────────────────────────────────
    ItemUnit('pièce', 'Pièce', 'Comptage'),
    ItemUnit('lot', 'Lot', 'Comptage'),
    ItemUnit('paire', 'Paire', 'Comptage'),
    ItemUnit('jeu', 'Jeu', 'Comptage'),

    // ── Conditionnements ──────────────────────────────────────────────────
    ItemUnit('carton', 'Carton', 'Conditionnement'),
    ItemUnit('boîte', 'Boîte', 'Conditionnement'),
    ItemUnit('paquet', 'Paquet', 'Conditionnement'),
    ItemUnit('sac', 'Sac', 'Conditionnement'),
    ItemUnit('caisse', 'Caisse', 'Conditionnement'),
    ItemUnit('palette', 'Palette', 'Conditionnement'),
    ItemUnit('rouleau', 'Rouleau', 'Conditionnement'),
    ItemUnit('bouteille', 'Bouteille', 'Conditionnement'),
    ItemUnit('bidon', 'Bidon', 'Conditionnement'),
    ItemUnit('fût', 'Fût', 'Conditionnement'),

    // ── Masse ─────────────────────────────────────────────────────────────
    ItemUnit('kg', 'Kilogramme (kg)', 'Masse'),
    ItemUnit('g', 'Gramme (g)', 'Masse'),
    ItemUnit('tonne', 'Tonne', 'Masse'),

    // ── Volume ────────────────────────────────────────────────────────────
    ItemUnit('L', 'Litre (L)', 'Volume'),
    ItemUnit('mL', 'Millilitre (mL)', 'Volume'),

    // ── Dimensions ────────────────────────────────────────────────────────
    ItemUnit('m', 'Mètre (m)', 'Dimensions'),
    ItemUnit('cm', 'Centimètre (cm)', 'Dimensions'),
    ItemUnit('m²', 'Mètre carré (m²)', 'Dimensions'),
    ItemUnit('m³', 'Mètre cube (m³)', 'Dimensions'),

    // ── Durée (location, prestation) ──────────────────────────────────────
    ItemUnit('heure', 'Heure', 'Durée'),
    ItemUnit('jour', 'Jour', 'Durée'),
  ];

  /// Valeurs connues, pour savoir si une unité saisie vient de la liste.
  static final Set<String> _values = {for (final u in all) u.value};

  static bool isKnown(String value) => _values.contains(value);

  /// Retrouve une unité existante quelle que soit sa casse ou ses espaces.
  ///
  /// Les articles créés avant l'introduction de la liste contiennent des
  /// valeurs comme `Kg` ou ` piece `. Les rattacher à l'entrée correspondante
  /// évite de les afficher comme des unités personnalisées.
  static String? normalize(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (_values.contains(value)) return value;

    final lower = value.toLowerCase();
    for (final unit in all) {
      if (unit.value.toLowerCase() == lower) return unit.value;
    }
    // Tolère les formes longues courantes de la saisie libre historique.
    const alias = {
      'piece': 'pièce',
      'pièces': 'pièce',
      'pieces': 'pièce',
      'u': 'pièce',
      'unite': 'pièce',
      'unité': 'pièce',
      'kilo': 'kg',
      'kilos': 'kg',
      'kilogramme': 'kg',
      'kilogrammes': 'kg',
      'gramme': 'g',
      'grammes': 'g',
      'litre': 'L',
      'litres': 'L',
      'l': 'L',
      'ml': 'mL',
      'millilitre': 'mL',
      'metre': 'm',
      'mètre': 'm',
      'boite': 'boîte',
      'fut': 'fût',
    };
    return alias[lower];
  }

  /// Libellé lisible d'une unité, y compris personnalisée.
  static String labelFor(String value) {
    final normalized = normalize(value);
    if (normalized == null) return value;
    return all.firstWhere((u) => u.value == normalized).label;
  }

  /// Groupes dans l'ordre d'affichage.
  static List<String> get groups {
    final seen = <String>[];
    for (final unit in all) {
      if (!seen.contains(unit.group)) seen.add(unit.group);
    }
    return seen;
  }

  static List<ItemUnit> inGroup(String group) =>
      all.where((u) => u.group == group).toList();
}
