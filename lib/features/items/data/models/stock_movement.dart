/// Mouvement de stock — `StockMovementSerializer` (US-08 à US-12).
class StockMovementModel {
  final String id;
  final String type;
  final int quantite;
  final String motif;
  final String reference;
  final String itemNom;
  final String acteurNom;
  final String? date;

  const StockMovementModel({
    required this.id,
    required this.type,
    required this.quantite,
    this.motif = '',
    this.reference = '',
    required this.itemNom,
    this.acteurNom = '',
    this.date,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    final acteur = json['acteur'];
    final acteurNom = acteur is Map<String, dynamic>
        ? _joinNom(acteur['first_name'], acteur['last_name'])
        : '';
    return StockMovementModel(
      id: json['id'] as String,
      type: json['type'] as String,
      quantite: (json['quantite'] as num).toInt(),
      motif: (json['motif'] as String?) ?? '',
      reference: (json['reference'] as String?) ?? '',
      itemNom: (json['item_nom'] as String?) ?? '',
      acteurNom: acteurNom.isNotEmpty
          ? acteurNom
          : (acteur is Map<String, dynamic>
              ? (acteur['email'] as String?) ?? ''
              : ''),
      date: json['date'] as String?,
    );
  }

  static String _joinNom(dynamic first, dynamic last) {
    final parts = [
      if (first is String && first.isNotEmpty) first,
      if (last is String && last.isNotEmpty) last,
    ];
    return parts.join(' ');
  }

  /// Date formatée en français (jj/MM/aaaa HH:mm).
  String get dateFr {
    final raw = date;
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  /// Libellé français du type de mouvement.
  String get typeLabel {
    switch (type) {
      case 'ENTREE':
        return 'Entrée';
      case 'SORTIE':
        return 'Sortie';
      case 'RETOUR':
        return 'Retour';
      case 'PERTE':
        return 'Perte';
      case 'DOMMAGE':
        return 'Dommage';
      case 'AJUSTEMENT':
        return 'Ajustement';
      default:
        return type;
    }
  }
}