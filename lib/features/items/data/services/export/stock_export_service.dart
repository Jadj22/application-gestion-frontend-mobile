import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dodome/core/offline/entity_registry.dart';
import 'package:dodome/core/offline/offline_repository.dart';
import 'package:dodome/features/business/data/models/business.dart';
import 'generators/stock_docx_generator.dart';
import 'generators/stock_excel_generator.dart';
import 'generators/stock_pdf_generator.dart';
import 'stock_export_models.dart';

/// Service central d'exportation d'inventaire multi-format en Offline-First.
class StockExportService {
  final OfflineRepository _offline;
  final StockExcelGenerator excelGenerator;
  final StockPdfGenerator pdfGenerator;
  final StockDocxGenerator docxGenerator;

  StockExportService(
    this._offline, {
    this.excelGenerator = const StockExcelGenerator(),
    this.pdfGenerator = const StockPdfGenerator(),
    this.docxGenerator = const StockDocxGenerator(),
  });

  /// Récupère l'ensemble des données d'inventaire directement depuis la base
  /// locale SQLite pour garantir un fonctionnement hors-ligne et l'isolation
  /// stricte par [Business.id].
  Future<StockExportData> prepareExportData(Business business) async {
    final results = await Future.wait([
      _offline.readCollection(EntityRegistry.item, business.id),
      _offline.readCollection(EntityRegistry.stockState, business.id),
    ]);

    final itemRows = results[0];
    final stockRows = results[1];

    final stockByItem = <String, Map<String, dynamic>>{
      for (final s in stockRows)
        if (s['item_id'] is String) s['item_id'] as String: s,
    };

    final rows = <StockExportRow>[];

    for (final json in itemRows) {
      final id = json['id'] as String? ?? '';
      if (id.isEmpty) continue;

      final nom = (json['nom'] as String?) ?? 'Sans nom';
      final sku = (json['reference'] as String?) ?? '';
      final description = (json['description'] as String?) ?? '';
      final rawPrix = json['prix'];
      final num prix = rawPrix is num ? rawPrix : (num.tryParse('$rawPrix') ?? 0);
      final unite = (json['unite'] as String?) ?? 'unité';
      final statut = (json['statut'] as String?) ?? 'ACTIF';

      final catRaw = json['category'];
      String categoryName = 'Non classé';
      if (catRaw is Map<String, dynamic>) {
        categoryName = (catRaw['nom'] as String?) ?? 'Non classé';
      } else if (json['category_nom'] is String) {
        categoryName = json['category_nom'] as String;
      }

      final stock = stockByItem[id] ?? const {};
      final total = (stock['total'] as num?)?.toInt() ?? 0;
      final disponibles = (stock['disponibles'] as num?)?.toInt() ?? 0;
      final sorties = (stock['sorties'] as num?)?.toInt() ?? 0;
      final endommages = (stock['endommages'] as num?)?.toInt() ?? 0;
      final perdus = (stock['perdus'] as num?)?.toInt() ?? 0;
      final rawEtat = stock['etat_entretien'];
      final etatEntretien = rawEtat != null ? '$rawEtat' : '—';

      rows.add(
        StockExportRow(
          id: id,
          nom: nom,
          sku: sku,
          categorie: categoryName,
          description: description,
          prix: prix,
          unite: unite,
          total: total,
          disponibles: disponibles,
          sorties: sorties,
          endommages: endommages,
          perdus: perdus,
          statut: statut,
          etatEntretien: etatEntretien,
        ),
      );
    }

    // Tri alphabétique par nom d'article pour la lisibilité
    rows.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

    final summary = StockExportSummary.fromRows(
      businessId: business.id,
      businessName: business.nom,
      businessPhone: business.telephone,
      businessEmail: business.email,
      rows: rows,
    );

    return StockExportData(summary: summary, rows: rows);
  }

  /// Génère le fichier dans le format demandé et le sauvegarde dans le stockage temporaire de l'appareil.
  Future<StockExportResult> exportStock({
    required Business business,
    required StockExportFormat format,
  }) async {
    final data = await prepareExportData(business);
    final Uint8List bytes;

    switch (format) {
      case StockExportFormat.xlsx:
        bytes = excelGenerator.generate(data);
        break;
      case StockExportFormat.pdf:
        bytes = await pdfGenerator.generate(data);
        break;
      case StockExportFormat.docx:
        bytes = docxGenerator.generate(data);
        break;
    }

    final dateStr = DateFormat('yyyyMMdd_HHmm').format(data.summary.generatedAt);
    final sanitizedBusinessName = business.nom
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');

    final fileName = 'inventaire_${sanitizedBusinessName}_$dateStr.${format.extension}';
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return StockExportResult(
      filePath: file.path,
      fileName: fileName,
      format: format,
      rowCount: data.rows.length,
      bytes: bytes,
    );
  }

  /// Ouvre la boîte de partage native du téléphone (WhatsApp, Email, Drive, etc.).
  Future<void> shareExport(StockExportResult result) async {
    final xFile = XFile(
      result.filePath,
      name: result.fileName,
      mimeType: result.format.mimeType,
    );
    await Share.shareXFiles(
      [xFile],
      subject: 'Inventaire des stocks - ${result.fileName}',
      text: 'Veuillez trouver ci-joint l\'export de l\'inventaire des stocks DODOME.',
    );
  }

  /// Imprime directement le document (uniquement pour le format PDF).
  Future<void> printPdf(StockExportResult result) async {
    if (result.format != StockExportFormat.pdf) {
      throw UnsupportedError('L\'impression directe n\'est prise en charge que pour le format PDF.');
    }
    await Printing.layoutPdf(
      onLayout: (_) async => result.bytes,
      name: result.fileName,
    );
  }
}
