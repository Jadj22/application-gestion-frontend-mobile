import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../data/items_repository.dart';
import '../../data/models/category.dart';
import '../../data/models/item.dart';

/// Page d'export des QR codes en lot.
/// Permet de sélectionner une catégorie et générer un PDF avec tous les QR codes.
class QrExportPage extends StatefulWidget {
  const QrExportPage({super.key});

  @override
  State<QrExportPage> createState() => _QrExportPageState();
}

class _QrExportPageState extends State<QrExportPage> {
  List<CategoryModel> _categories = [];
  List<ItemModel> _allItems = [];
  String? _selectedCategoryId;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) throw Exception('Business non sélectionné');

      final repo = context.read<ItemsRepository>();
      final results = await Future.wait([
        repo.categories(businessId),
        repo.items(businessId),
      ]);

      setState(() {
        _categories = results[0] as List<CategoryModel>;
        _allItems = results[1] as List<ItemModel>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ItemModel> get _filteredItems {
    if (_selectedCategoryId == null) {
      return _allItems;
    }
    return _allItems
        .where((item) => item.categoryId == _selectedCategoryId)
        .toList();
  }

  List<ItemModel> get _itemsWithQrCode {
    return _filteredItems.where((item) => item.qrCode != null && item.qrCode!.isNotEmpty).toList();
  }

  Future<void> _generateAndPrintPdf() async {
    final items = _itemsWithQrCode;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun article avec QR code à exporter')),
      );
      return;
    }

    setState(() => _generating = true);

    try {
      final pdf = pw.Document();

      // Générer les QR codes par lots de 6 par page (2x3)
      const itemsPerPage = 6;
      final pageCount = (items.length / itemsPerPage).ceil();

      for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        final startIndex = pageIndex * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, items.length);
        final pageItems = items.sublist(startIndex, endIndex);

        final qrImages = await Future.wait(
          pageItems.map((item) => _generateQrImageBytes(item.qrCode!)),
        );

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'QR Codes - ${_selectedCategoryId != null ? _getCategoryName(_selectedCategoryId!) : "Tous les articles"}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Page ${pageIndex + 1} sur $pageCount',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Expanded(
                    child: pw.GridView(
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: 0.85,
                      children: [
                        for (var i = 0; i < pageItems.length; i++)
                          _buildPdfQrCard(pageItems[i], qrImages[i]),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Afficher l'aperçu d'impression
      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name: 'qr_codes_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${items.length} QR codes exportés')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<pw.MemoryImage> _generateQrImageBytes(String data) async {
    final qrValidationResult = QrValidator.validate(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );

    final painter = QrPainter.withQr(
      qr: qrValidationResult.qrCode!,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF000000),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF000000),
      ),
    );

    final image = await painter.toImage(200);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return pw.MemoryImage(byteData!.buffer.asUint8List());
  }

  pw.Widget _buildPdfQrCard(ItemModel item, pw.MemoryImage qrImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Image(qrImage, width: 100, height: 100),
          pw.SizedBox(height: 8),
          pw.Text(
            item.nom,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
          ),
          if (item.reference != null && item.reference!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Réf: ${item.reference}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              item.qrCode!,
              style: const pw.TextStyle(fontSize: 6),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String categoryId) {
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => const CategoryModel(id: '', nom: 'Catégorie'),
    );
    return category.nom;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export QR Codes'),
        actions: [
          if (!_loading && _itemsWithQrCode.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Erreur: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.dashPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.dashPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.dashPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sélectionnez une catégorie pour exporter les QR codes de tous ses articles en PDF.',
                    style: TextStyle(color: AppColors.dashPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sélecteur de catégorie
          const Text(
            'Catégorie',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.dashOutlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedCategoryId,
                isExpanded: true,
                hint: const Text('Toutes les catégories'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Toutes les catégories'),
                  ),
                  ..._categories.map((cat) => DropdownMenuItem<String?>(
                        value: cat.id,
                        child: Text(cat.nom),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Résumé
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.dashOutlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Résumé',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  'Articles dans la sélection',
                  '${_filteredItems.length}',
                ),
                _buildSummaryRow(
                  'Articles avec QR code',
                  '${_itemsWithQrCode.length}',
                  highlight: true,
                ),
                _buildSummaryRow(
                  'Pages PDF estimées',
                  '${(_itemsWithQrCode.length / 6).ceil()}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Aperçu des articles
          if (_itemsWithQrCode.isNotEmpty) ...[
            Row(
              children: [
                const Text(
                  'Aperçu',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_itemsWithQrCode.length} article(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _itemsWithQrCode.length > 9 ? 9 : _itemsWithQrCode.length,
              itemBuilder: (context, index) {
                final item = _itemsWithQrCode[index];
                return _QrPreviewCard(item: item);
              },
            ),
            if (_itemsWithQrCode.length > 9)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    '+ ${_itemsWithQrCode.length - 9} autres articles',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun article avec QR code',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Les QR codes sont générés automatiquement',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? AppColors.dashPrimary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_loading || _itemsWithQrCode.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton.icon(
          onPressed: _generating ? null : _generateAndPrintPdf,
          icon: _generating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print),
          label: Text(
            _generating
                ? 'Génération en cours...'
                : 'Générer PDF (${_itemsWithQrCode.length} QR codes)',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.dashPrimary,
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ),
    );
  }
}

class _QrPreviewCard extends StatelessWidget {
  final ItemModel item;

  const _QrPreviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item.qrCode != null)
            QrImageView(
              data: item.qrCode!,
              version: QrVersions.auto,
              size: 60,
              backgroundColor: Colors.white,
            ),
          const SizedBox(height: 4),
          Text(
            item.nom,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
