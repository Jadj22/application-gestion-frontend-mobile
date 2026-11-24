import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../stock_export_models.dart';

/// Générateur de document Microsoft Word (.docx) authentique et conforme
/// à la norme ECMA-376 (OpenXML / WordprocessingML).
class StockDocxGenerator {
  const StockDocxGenerator();

  /// Génère le fichier DOCX sous forme d'octets.
  Uint8List generate(StockExportData data) {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = _buildContentTypesXml();
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    final packageRelsXml = _buildPackageRelsXml();
    archive.addFile(ArchiveFile('_rels/.rels', packageRelsXml.length, utf8.encode(packageRelsXml)));

    // 3. word/_rels/document.xml.rels
    final documentRelsXml = _buildDocumentRelsXml();
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', documentRelsXml.length, utf8.encode(documentRelsXml)));

    // 4. word/styles.xml
    final stylesXml = _buildStylesXml();
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 5. word/document.xml
    final documentXml = _buildDocumentXml(data);
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded ?? []);
  }

  // ── XML Builders ─────────────────────────────────────────────────────────

  String _buildContentTypesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
  }

  String _buildPackageRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
  }

  String _buildDocumentRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
  }

  String _buildStylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="20"/>
        <w:szCs w:val="20"/>
        <w:lang w:val="fr-FR"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:pPr>
      <w:spacing w:before="240" w:after="120"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:b/>
      <w:color w:val="005F56"/>
      <w:sz w:val="32"/>
    </w:rPr>
  </w:style>
</w:styles>''';
  }

  String _buildDocumentXml(StockExportData data) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat('#,##0.00');

    final buffer = StringBuffer();
    buffer.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>''');

    // Titre
    buffer.write('''
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1"/>
      </w:pPr>
      <w:r>
        <w:t>Rapport d'inventaire des stocks</w:t>
      </w:r>
    </w:p>''');

    // Métadonnées
    buffer.write('''
    <w:p>
      <w:r>
        <w:rPr><w:b/><w:color w:val="005F56"/></w:rPr>
        <w:t>Entreprise : ${_escapeXml(data.summary.businessName)}</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r>
        <w:rPr><w:color w:val="64748B"/></w:rPr>
        <w:t>Date d'exportation : ${dateFormat.format(data.summary.generatedAt)} | Système : DODOME Mobile (Hors ligne)</w:t>
      </w:r>
    </w:p>''');

    if (data.summary.businessPhone != null && data.summary.businessPhone!.isNotEmpty) {
      buffer.write('''
    <w:p>
      <w:r>
        <w:rPr><w:color w:val="64748B"/></w:rPr>
        <w:t>Téléphone : ${_escapeXml(data.summary.businessPhone!)}</w:t>
      </w:r>
    </w:p>''');
    }

    // Récapitulatif
    buffer.write('''
    <w:p><w:pPr><w:spacing w:before="120" w:after="200"/></w:pPr>
      <w:r>
        <w:rPr><w:b/></w:rPr>
        <w:t>Synthèse globale : ${data.summary.totalArticles} articles | ${data.summary.totalUnits} pièces inventoriées | ${data.summary.totalDisponibles} disponibles | ${data.summary.totalSorties} sorties | Valeur totale : ${currencyFormat.format(data.summary.totalValuation)} F CFA</w:t>
      </w:r>
    </w:p>''');

    // Tableau des articles
    buffer.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="600"/>
        <w:gridCol w:w="2600"/>
        <w:gridCol w:w="1600"/>
        <w:gridCol w:w="1600"/>
        <w:gridCol w:w="1200"/>
        <w:gridCol w:w="800"/>
        <w:gridCol w:w="1000"/>
        <w:gridCol w:w="1000"/>
        <w:gridCol w:w="900"/>
        <w:gridCol w:w="900"/>
        <w:gridCol w:w="1500"/>
        <w:gridCol w:w="1100"/>
      </w:tblGrid>''');

    // Ligne d'en-tête (répétée en haut de chaque page)
    buffer.write('''
      <w:tr>
        <w:trPr>
          <w:tblHeader/>
        </w:trPr>''');

    final headers = [
      ('N°', 'center'),
      ('Article', 'left'),
      ('Réf (SKU)', 'left'),
      ('Catégorie', 'left'),
      ('P.U.', 'right'),
      ('Unité', 'center'),
      ('Total', 'right'),
      ('Dispo.', 'right'),
      ('Sorties', 'right'),
      ('Endomm.', 'right'),
      ('Valeur', 'right'),
      ('Statut', 'center'),
    ];

    for (final h in headers) {
      buffer.write('''
        <w:tc>
          <w:tcPr>
            <w:shd w:val="clear" w:color="auto" w:fill="005F56"/>
          </w:tcPr>
          <w:p>
            <w:pPr><w:jc w:val="${h.$2}"/></w:pPr>
            <w:r>
              <w:rPr>
                <w:b/>
                <w:color w:val="FFFFFF"/>
                <w:sz w:val="18"/>
              </w:rPr>
              <w:t>${_escapeXml(h.$1)}</w:t>
            </w:r>
          </w:p>
        </w:tc>''');
    }
    buffer.write('</w:tr>');

    // Données
    for (var i = 0; i < data.rows.length; i++) {
      final r = data.rows[i];
      final isAlternate = i % 2 == 1;
      final fill = isAlternate ? 'F8FAFC' : 'FFFFFF';

      buffer.write('<w:tr>');

      final cells = [
        ('${i + 1}', 'center'),
        (r.nom, 'left'),
        (r.sku.isEmpty ? '—' : r.sku, 'left'),
        (r.categorie, 'left'),
        (currencyFormat.format(r.prix), 'right'),
        (r.unite, 'center'),
        ('${r.total}', 'right'),
        ('${r.disponibles}', 'right'),
        ('${r.sorties}', 'right'),
        ('${r.endommages}', 'right'),
        (currencyFormat.format(r.valeurTotale), 'right'),
        (r.statut, 'center'),
      ];

      for (final c in cells) {
        buffer.write('''
        <w:tc>
          <w:tcPr>
            <w:shd w:val="clear" w:color="auto" w:fill="$fill"/>
          </w:tcPr>
          <w:p>
            <w:pPr><w:jc w:val="${c.$2}"/></w:pPr>
            <w:r>
              <w:rPr><w:sz w:val="17"/></w:rPr>
              <w:t>${_escapeXml(c.$1)}</w:t>
            </w:r>
          </w:p>
        </w:tc>''');
      }

      buffer.write('</w:tr>');
    }

    // Ligne de totaux
    buffer.write('''
      <w:tr>
        <w:tc>
          <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr>
          <w:p><w:r><w:rPr><w:b/><w:sz w:val="17"/></w:rPr><w:t></w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr>
          <w:p><w:r><w:rPr><w:b/><w:color w:val="005F56"/><w:sz w:val="17"/></w:rPr><w:t>TOTAL</w:t></w:r></w:p>
        </w:tc>
        <w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc>
          <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="005F56"/><w:sz w:val="17"/></w:rPr><w:t>${data.summary.totalUnits}</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="005F56"/><w:sz w:val="17"/></w:rPr><w:t>${data.summary.totalDisponibles}</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="005F56"/><w:sz w:val="17"/></w:rPr><w:t>${data.summary.totalSorties}</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="005F56"/><w:sz w:val="17"/></w:rPr><w:t>${data.summary.totalEndommages}</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="005F56"/><w:sz w:val="17"/></w:rPr><w:t>${currencyFormat.format(data.summary.totalValuation)}</w:t></w:r></w:p>
        </w:tc>
        <w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="E6F4F1"/></w:tcPr><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
      </w:tr>''');

    buffer.write('</w:tbl>');

    // Format de page A4 Paysage
    buffer.write('''
    <w:sectPr>
      <w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>
      <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="720" w:footer="720"/>
    </w:sectPr>''');

    buffer.write('''
  </w:body>
</w:document>''');

    return buffer.toString();
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
