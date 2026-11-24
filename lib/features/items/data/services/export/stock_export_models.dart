import 'dart:typed_data';

/// Formats d'exportation pris en charge.
enum StockExportFormat {
  xlsx('Excel', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  pdf('PDF', 'pdf', 'application/pdf'),
  docx('Word', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');

  final String label;
  final String extension;
  final String mimeType;

  const StockExportFormat(this.label, this.extension, this.mimeType);
}

/// Ligne de données consolidée représentant un article dans l'inventaire.
class StockExportRow {
  final String id;
  final String nom;
  final String sku;
  final String categorie;
  final String description;
  final num prix;
  final String unite;
  final int total;
  final int disponibles;
  final int sorties;
  final int endommages;
  final int perdus;
  final String statut;
  final String etatEntretien;

  const StockExportRow({
    required this.id,
    required this.nom,
    this.sku = '',
    this.categorie = 'Non classé',
    this.description = '',
    this.prix = 0,
    this.unite = 'unité',
    this.total = 0,
    this.disponibles = 0,
    this.sorties = 0,
    this.endommages = 0,
    this.perdus = 0,
    this.statut = 'ACTIF',
    this.etatEntretien = '—',
  });

  /// Valeur estimée en stock pour cet article (total * prix unitaire).
  num get valeurTotale => total * prix;
}

/// Informations récapitulatives sur le business et le stock au moment de l'export.
class StockExportSummary {
  final String businessId;
  final String businessName;
  final String? businessAddress;
  final String? businessPhone;
  final String? businessEmail;
  final DateTime generatedAt;
  final int totalArticles;
  final int totalUnits;
  final int totalDisponibles;
  final int totalSorties;
  final int totalEndommages;
  final num totalValuation;

  const StockExportSummary({
    required this.businessId,
    required this.businessName,
    this.businessAddress,
    this.businessPhone,
    this.businessEmail,
    required this.generatedAt,
    required this.totalArticles,
    required this.totalUnits,
    required this.totalDisponibles,
    required this.totalSorties,
    required this.totalEndommages,
    required this.totalValuation,
  });

  factory StockExportSummary.fromRows({
    required String businessId,
    required String businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    required List<StockExportRow> rows,
  }) {
    var totalUnits = 0;
    var totalDisponibles = 0;
    var totalSorties = 0;
    var totalEndommages = 0;
    num totalValuation = 0;

    for (final r in rows) {
      totalUnits += r.total;
      totalDisponibles += r.disponibles;
      totalSorties += r.sorties;
      totalEndommages += r.endommages;
      totalValuation += r.valeurTotale;
    }

    return StockExportSummary(
      businessId: businessId,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
      generatedAt: DateTime.now(),
      totalArticles: rows.length,
      totalUnits: totalUnits,
      totalDisponibles: totalDisponibles,
      totalSorties: totalSorties,
      totalEndommages: totalEndommages,
      totalValuation: totalValuation,
    );
  }
}

/// Conteneur de données prêt à être passé aux générateurs de documents.
class StockExportData {
  final StockExportSummary summary;
  final List<StockExportRow> rows;

  const StockExportData({
    required this.summary,
    required this.rows,
  });

  bool get isEmpty => rows.isEmpty;
}

/// Résultat d'une génération de fichier d'export.
class StockExportResult {
  final String filePath;
  final String fileName;
  final StockExportFormat format;
  final int rowCount;
  final Uint8List bytes;

  const StockExportResult({
    required this.filePath,
    required this.fileName,
    required this.format,
    required this.rowCount,
    required this.bytes,
  });
}
