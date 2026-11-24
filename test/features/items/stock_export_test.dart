import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodome/features/items/data/services/export/generators/stock_docx_generator.dart';
import 'package:dodome/features/items/data/services/export/generators/stock_excel_generator.dart';
import 'package:dodome/features/items/data/services/export/generators/stock_pdf_generator.dart';
import 'package:dodome/features/items/data/services/export/stock_export_models.dart';

void main() {
  group('Stock Export Generators Test', () {
    final sampleRows = [
      const StockExportRow(
        id: 'item-1',
        nom: 'Tente Événementielle 5x5m',
        sku: 'TNT-55-EVT',
        categorie: 'Structures & Tentes',
        description: 'Tente blanche imperméable avec armatures métalliques',
        prix: 25000,
        unite: 'pièce',
        total: 10,
        disponibles: 7,
        sorties: 2,
        endommages: 1,
        perdus: 0,
        statut: 'ACTIF',
        etatEntretien: 'Bon',
      ),
      const StockExportRow(
        id: 'item-2',
        nom: 'Chaises Plastiques "Grand Confort" <Éco>',
        sku: '',
        categorie: 'Mobilier',
        description: 'Chaises empilables couleur crème',
        prix: 500,
        unite: 'unité',
        total: 100,
        disponibles: 90,
        sorties: 10,
        endommages: 0,
        perdus: 0,
        statut: 'ACTIF',
        etatEntretien: '—',
      ),
      const StockExportRow(
        id: 'item-3',
        nom: 'Article Spécial & Accents : café, thé & gâteaux',
        sku: 'SPEC-01',
        categorie: 'Divers',
        description: '',
        prix: 0,
        unite: 'lot',
        total: 0,
        disponibles: 0,
        sorties: 0,
        endommages: 0,
        perdus: 0,
        statut: 'INACTIF',
        etatEntretien: '—',
      ),
    ];

    final summary = StockExportSummary.fromRows(
      businessId: 'biz-test-123',
      businessName: 'DODOME Location & Déco',
      businessPhone: '+228 90 00 00 00',
      businessEmail: 'contact@dodome.test',
      rows: sampleRows,
    );

    final exportData = StockExportData(summary: summary, rows: sampleRows);

    test('StockExcelGenerator generates valid XLSX bytes with proper data', () {
      const generator = StockExcelGenerator();
      final bytes = generator.generate(exportData);

      expect(bytes, isNotEmpty);
      // XLSX is a ZIP package starting with PK (0x50, 0x4B)
      expect(bytes[0], equals(0x50));
      expect(bytes[1], equals(0x4B));
    });

    test('StockPdfGenerator generates valid PDF bytes starting with %PDF', () async {
      const generator = StockPdfGenerator();
      final bytes = await generator.generate(exportData);

      expect(bytes, isNotEmpty);
      final header = utf8.decode(bytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });

    test('StockDocxGenerator generates valid OpenXML DOCX archive', () {
      const generator = StockDocxGenerator();
      final bytes = generator.generate(exportData);

      expect(bytes, isNotEmpty);
      // DOCX is a ZIP package starting with PK
      expect(bytes[0], equals(0x50));
      expect(bytes[1], equals(0x4B));

      // Decode ZIP archive to verify internal files
      final archive = ZipDecoder().decodeBytes(bytes);
      final fileNames = archive.files.map((f) => f.name).toSet();

      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('_rels/.rels'));
      expect(fileNames, contains('word/_rels/document.xml.rels'));
      expect(fileNames, contains('word/styles.xml'));
      expect(fileNames, contains('word/document.xml'));

      // Check document.xml content has escaped text and table structure
      final docFile = archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final docXml = utf8.decode(docFile.content as List<int>);

      expect(docXml, contains('Tente'));
      expect(docXml, contains('DODOME Location'));
      // Verify XML special characters were escaped properly
      expect(docXml, contains('&amp;'));
      expect(docXml, contains('&lt;'));
      expect(docXml, contains('&gt;'));
      expect(docXml, contains('&quot;'));
      expect(docXml, isNot(contains('<Éco>')));
    });

    test('Stock generators handle empty inventory gracefully', () async {
      final emptySummary = StockExportSummary.fromRows(
        businessId: 'biz-empty',
        businessName: 'Boutique Vide',
        rows: [],
      );
      final emptyData = StockExportData(summary: emptySummary, rows: []);

      const excelGen = StockExcelGenerator();
      final xlsxBytes = excelGen.generate(emptyData);
      expect(xlsxBytes, isNotEmpty);

      const pdfGen = StockPdfGenerator();
      final pdfBytes = await pdfGen.generate(emptyData);
      expect(pdfBytes, isNotEmpty);

      const docxGen = StockDocxGenerator();
      final docxBytes = docxGen.generate(emptyData);
      expect(docxBytes, isNotEmpty);
    });
  });
}
