import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/offline/offline_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../business/data/models/business.dart';
import '../../data/services/export/stock_export_models.dart';
import '../../data/services/export/stock_export_service.dart';

/// Feuille modale pour sélectionner le format d'export et exécuter l'action.
class StockExportBottomSheet extends StatefulWidget {
  final Business business;

  const StockExportBottomSheet({super.key, required this.business});

  static Future<void> show(BuildContext context, Business business) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StockExportBottomSheet(business: business),
    );
  }

  @override
  State<StockExportBottomSheet> createState() => _StockExportBottomSheetState();
}

class _StockExportBottomSheetState extends State<StockExportBottomSheet> {
  late final StockExportService _exportService;
  bool _isGenerating = false;
  StockExportFormat? _generatingFormat;
  StockExportResult? _lastResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final offline = context.read<OfflineRepository>();
    _exportService = StockExportService(offline);
  }

  Future<void> _handleExport(StockExportFormat format) async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _generatingFormat = format;
      _errorMessage = null;
      _lastResult = null;
    });

    try {
      final result = await _exportService.exportStock(
        business: widget.business,
        format: format,
      );
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generatingFormat = null;
        _lastResult = result;
      });
      // Ouvrir immédiatement le partage pour une action fluide
      await _exportService.shareExport(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generatingFormat = null;
        _errorMessage = 'Échec de la génération : $e';
      });
    }
  }

  Future<void> _handlePrint() async {
    final result = _lastResult;
    if (result == null || result.format != StockExportFormat.pdf) return;
    try {
      await _exportService.printPdf(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'impression : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre d'accroche visuelle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dashPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.dashPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exporter les stocks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dashPrimary,
                        ),
                      ),
                      Text(
                        'Génération hors-ligne (${widget.business.nom})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Fermer',
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_isGenerating) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.dashPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.dashPrimary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Génération du fichier ${_generatingFormat?.label ?? ''} en cours…',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.dashPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Vos données locales sont en cours de mise en page.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else if (_lastResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF005F56).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF005F56), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fichier ${_lastResult!.format.label} prêt !',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF005F56),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_lastResult!.rowCount} article(s) inclus dans ${_lastResult!.fileName}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.dashPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Partager'),
                            onPressed: () => _exportService.shareExport(_lastResult!),
                          ),
                        ),
                        if (_lastResult!.format == StockExportFormat.pdf) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.dashPrimary,
                                side: const BorderSide(color: AppColors.dashPrimary),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text('Imprimer'),
                              onPressed: _handlePrint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Exporter dans un autre format :',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              _buildFormatTiles(),
            ] else ...[
              _buildFormatTiles(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormatTiles() {
    return Column(
      children: [
        _FormatCard(
          icon: Icons.table_chart_outlined,
          color: const Color(0xFF107C41),
          title: 'Excel (.xlsx)',
          subtitle: 'Tableau complet avec totaux, compatible Excel & Sheets',
          onTap: () => _handleExport(StockExportFormat.xlsx),
        ),
        const SizedBox(height: 10),
        _FormatCard(
          icon: Icons.picture_as_pdf_outlined,
          color: const Color(0xFFD93025),
          title: 'PDF (.pdf)',
          subtitle: 'Mise en page paysage prête à imprimer et archiver',
          onTap: () => _handleExport(StockExportFormat.pdf),
        ),
        const SizedBox(height: 10),
        _FormatCard(
          icon: Icons.description_outlined,
          color: const Color(0xFF185ABD),
          title: 'Word (.docx)',
          subtitle: 'Document structuré et modifiable OpenXML',
          onTap: () => _handleExport(StockExportFormat.docx),
        ),
      ],
    );
  }
}

class _FormatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FormatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
