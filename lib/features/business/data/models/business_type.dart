/// Type de business — `BusinessTypeSerializer` (étape 1 du tunnel).
class BusinessType {
  final String codename;
  final String libelle;

  const BusinessType({required this.codename, required this.libelle});

  factory BusinessType.fromJson(Map<String, dynamic> json) => BusinessType(
        codename: json['codename'] as String,
        libelle: json['libelle'] as String,
      );

  String get iconLabel {
    switch (codename) {
      case 'DECORATION_RENTAL':
        return 'decoration';
      case 'GENERAL_INVENTORY':
        return 'inventory';
      default:
        return 'business';
    }
  }
}