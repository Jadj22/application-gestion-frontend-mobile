import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../stock_export_models.dart';

/// Générateur de feuille de calcul Microsoft Excel (.xlsx) pour l'inventaire.
class StockExcelGenerator {
  const StockExcelGenerator();

  /// Génère le fichier XLSX en mémoire sous forme d'octets.
  Uint8List generate(StockExportData data) {
    final excel = Excel.createExcel();
    const sheetName = 'Inventaire';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // ── En-tête métadonnées du document ──────────────────────────────────────
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('RAPPORT D\'INVENTAIRE DES STOCKS')
      ..cellStyle = CellStyle(bold: true, fontSize: 14);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue('Entreprise : ${data.summary.businessName}')
      ..cellStyle = CellStyle(bold: true);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value =
        TextCellValue('Date de génération : ${dateFormat.format(data.summary.generatedAt)}');

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value =
        TextCellValue('Total articles : ${data.summary.totalArticles} | Unités en stock : ${data.summary.totalUnits} | Disponibles : ${data.summary.totalDisponibles}');

    // ── En-têtes des colonnes ────────────────────────────────────────────────
    final headers = [
      'N°',
      'Article',
      'Référence (SKU)',
      'Catégorie',
      'Description',
      'Prix unitaire',
      'Unité',
      'Stock Total',
      'Disponible',
      'Sorties',
      'Endommagé',
      'Entretien',
      'Valeur Totale',
      'Statut',
    ];

    const headerRowIndex = 5;
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#005F56'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRowIndex));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // ── Lignes de données ────────────────────────────────────────────────────
    var currentRow = headerRowIndex + 1;

    final alternateRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
    );

    for (var i = 0; i < data.rows.length; i++) {
      final row = data.rows[i];
      final isAlternate = i % 2 == 1;
      final rowStyle = isAlternate ? alternateRowStyle : null;

      void setCell(int col, CellValue value, [CellStyle? customStyle]) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        cell.value = value;
        if (customStyle != null) {
          cell.cellStyle = customStyle;
        } else if (rowStyle != null) {
          cell.cellStyle = rowStyle;
        }
      }

      setCell(0, IntCellValue(i + 1));
      setCell(1, TextCellValue(row.nom));
      setCell(2, TextCellValue(row.sku.isEmpty ? '—' : row.sku));
      setCell(3, TextCellValue(row.categorie));
      setCell(4, TextCellValue(row.description.isEmpty ? '—' : row.description));
      setCell(5, DoubleCellValue(row.prix.toDouble()));
      setCell(6, TextCellValue(row.unite));
      setCell(7, IntCellValue(row.total));
      setCell(8, IntCellValue(row.disponibles));
      setCell(9, IntCellValue(row.sorties));
      setCell(10, IntCellValue(row.endommages));
      setCell(11, TextCellValue(row.etatEntretien));
      setCell(12, DoubleCellValue(row.valeurTotale.toDouble()));
      setCell(13, TextCellValue(row.statut));

      currentRow++;
    }

    // ── Ligne de totaux ──────────────────────────────────────────────────────
    final totalRowStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#E6F4F1'),
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#005F56'),
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
      ..value = TextCellValue('TOTAL GÉNÉRAL')
      ..cellStyle = totalRowStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow))
      ..value = IntCellValue(data.summary.totalUnits)
      ..cellStyle = totalRowStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow))
      ..value = IntCellValue(data.summary.totalDisponibles)
      ..cellStyle = totalRowStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: currentRow))
      ..value = IntCellValue(data.summary.totalSorties)
      ..cellStyle = totalRowStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: currentRow))
      ..value = IntCellValue(data.summary.totalEndommages)
      ..cellStyle = totalRowStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: currentRow))
      ..value = DoubleCellValue(data.summary.totalValuation.toDouble())
      ..cellStyle = totalRowStyle;

    // ── Ajustement des largeurs de colonnes ──────────────────────────────────
    final colWidths = [6.0, 26.0, 16.0, 18.0, 30.0, 14.0, 10.0, 12.0, 12.0, 10.0, 12.0, 14.0, 16.0, 12.0];
    for (var col = 0; col < colWidths.length; col++) {
      sheet.setColumnWidth(col, colWidths[col]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }
}
