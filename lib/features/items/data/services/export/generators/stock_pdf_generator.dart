import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../stock_export_models.dart';

/// Générateur de document PDF professionnel pour l'inventaire des stocks.
class StockPdfGenerator {
  const StockPdfGenerator();

  /// Génère le document PDF sous forme d'octets.
  Future<Uint8List> generate(StockExportData data) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat('#,##0.00');

    const primaryColor = PdfColor.fromInt(0xFF005F56);
    const primaryLightColor = PdfColor.fromInt(0xFFE6F4F1);
    const borderColor = PdfColor.fromInt(0xFFCBD5E1);
    const textMutedColor = PdfColor.fromInt(0xFF64748B);

    final headers = [
      'N°',
      'Article',
      'Réf (SKU)',
      'Catégorie',
      'P.U.',
      'Unité',
      'Total',
      'Dispo.',
      'Sorties',
      'Endomm.',
      'Valeur',
      'Statut',
    ];

    final tableData = <List<String>>[];
    for (var i = 0; i < data.rows.length; i++) {
      final r = data.rows[i];
      tableData.add([
        '${i + 1}',
        r.nom,
        r.sku.isEmpty ? '-' : r.sku,
        r.categorie,
        currencyFormat.format(r.prix),
        r.unite,
        '${r.total}',
        '${r.disponibles}',
        '${r.sorties}',
        '${r.endommages}',
        currencyFormat.format(r.valeurTotale),
        r.statut,
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildPageHeader(
          data: data,
          dateFormat: dateFormat,
          primaryColor: primaryColor,
          textMutedColor: textMutedColor,
        ),
        footer: (context) => _buildPageFooter(
          context: context,
          textMutedColor: textMutedColor,
          generatedAt: data.summary.generatedAt,
          dateFormat: dateFormat,
        ),
        build: (context) => [
          _buildSummaryCards(
            data: data,
            primaryColor: primaryColor,
            primaryLightColor: primaryLightColor,
            borderColor: borderColor,
            currencyFormat: currencyFormat,
          ),
          pw.SizedBox(height: 16),
          if (data.rows.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Aucun article dans l\'inventaire.',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontStyle: pw.FontStyle.italic,
                  color: textMutedColor,
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: tableData,
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: primaryColor),
              headerHeight: 24,
              cellHeight: 20,
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.center,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
                9: pw.Alignment.centerRight,
                10: pw.Alignment.centerRight,
                11: pw.Alignment.center,
              },
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
              ),
            ),
          if (data.rows.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _buildTotalRow(
              data: data,
              primaryLightColor: primaryLightColor,
              borderColor: borderColor,
              currencyFormat: currencyFormat,
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPageHeader({
    required StockExportData data,
    required DateFormat dateFormat,
    required PdfColor primaryColor,
    required PdfColor textMutedColor,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF005F56), width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DODOME | GESTION DE STOCK',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Rapport d\'inventaire des stocks',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                data.summary.businessName,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              if (data.summary.businessPhone != null &&
                  data.summary.businessPhone!.isNotEmpty)
                pw.Text(
                  'Tél : ${data.summary.businessPhone}',
                  style: pw.TextStyle(fontSize: 8, color: textMutedColor),
                ),
              pw.Text(
                'Édité le ${dateFormat.format(data.summary.generatedAt)}',
                style: pw.TextStyle(fontSize: 8, color: textMutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPageFooter({
    required pw.Context context,
    required PdfColor textMutedColor,
    required DateTime generatedAt,
    required DateFormat dateFormat,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Document généré hors-ligne depuis l\'application mobile DODOME',
            style: pw.TextStyle(fontSize: 7.5, color: textMutedColor),
          ),
          pw.Text(
            'Page ${context.pageNumber} sur ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: textMutedColor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryCards({
    required StockExportData data,
    required PdfColor primaryColor,
    required PdfColor primaryLightColor,
    required PdfColor borderColor,
    required NumberFormat currencyFormat,
  }) {
    pw.Widget card(String title, String value, [String? subtitle]) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: primaryLightColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: borderColor, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              if (subtitle != null) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  subtitle,
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColor.fromInt(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        card('Articles', '${data.summary.totalArticles}', 'références en stock'),
        pw.SizedBox(width: 8),
        card('Unités Totales', '${data.summary.totalUnits}', 'pièces inventoriées'),
        pw.SizedBox(width: 8),
        card('Disponibles', '${data.summary.totalDisponibles}', 'immédiatement louables'),
        pw.SizedBox(width: 8),
        card('Sorties / Louées', '${data.summary.totalSorties}', 'en cours d\'utilisation'),
        pw.SizedBox(width: 8),
        card('Valeur Globale', '${currencyFormat.format(data.summary.totalValuation)} F', 'valeur d\'inventaire'),
      ],
    );
  }

  pw.Widget _buildTotalRow({
    required StockExportData data,
    required PdfColor primaryLightColor,
    required PdfColor borderColor,
    required NumberFormat currencyFormat,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: primaryLightColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TOTAL GÉNÉRAL (${data.summary.totalArticles} articles)',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF005F56),
            ),
          ),
          pw.Row(
            children: [
              pw.Text(
                'Total unités : ${data.summary.totalUnits}  |  Disponibles : ${data.summary.totalDisponibles}  |  Sorties : ${data.summary.totalSorties}  |  Valeur : ${currencyFormat.format(data.summary.totalValuation)} F',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF005F56),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
