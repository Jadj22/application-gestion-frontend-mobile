import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../../core/theme/app_colors.dart';

/// Widget pour afficher et partager le QR code d'un article.
class QrCodeDialog extends StatelessWidget {
  final String qrCode;
  final String itemName;
  final String? reference;

  const QrCodeDialog({
    super.key,
    required this.qrCode,
    required this.itemName,
    this.reference,
  });

  static Future<void> show(
    BuildContext context, {
    required String qrCode,
    required String itemName,
    String? reference,
  }) {
    return showDialog(
      context: context,
      builder: (_) => QrCodeDialog(
        qrCode: qrCode,
        itemName: itemName,
        reference: reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2, color: AppColors.dashPrimary),
                const SizedBox(width: 8),
                const Text(
                  'QR Code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _QrCodeCard(
              qrCode: qrCode,
              itemName: itemName,
              reference: reference,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareQrCode(context),
                    icon: const Icon(Icons.share),
                    label: const Text('Partager'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _saveQrCode(context),
                    icon: const Icon(Icons.download),
                    label: const Text('Enregistrer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dashPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareQrCode(BuildContext context) async {
    try {
      final imageBytes = await _generateQrImage();
      if (imageBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_$qrCode.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR Code: $itemName${reference != null ? ' (Réf: $reference)' : ''}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _saveQrCode(BuildContext context) async {
    try {
      final imageBytes = await _generateQrImage();
      if (imageBytes == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'qr_${itemName.replaceAll(' ', '_')}_$qrCode.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Code enregistré: $fileName')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _generateQrImage() async {
    final qrValidationResult = QrValidator.validate(
      data: qrCode,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );

    if (qrValidationResult.status != QrValidationStatus.valid) {
      return null;
    }

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

    final image = await painter.toImage(300);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

/// Carte QR code avec nom et référence.
class _QrCodeCard extends StatelessWidget {
  final String qrCode;
  final String itemName;
  final String? reference;

  const _QrCodeCard({
    required this.qrCode,
    required this.itemName,
    this.reference,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashOutlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          QrImageView(
            data: qrCode,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            errorStateBuilder: (context, error) => const Center(
              child: Text('Erreur de génération'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            itemName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (reference != null && reference!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Réf: $reference',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              qrCode,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget QR code compact pour les listes.
class QrCodeBadge extends StatelessWidget {
  final String? qrCode;
  final VoidCallback? onTap;

  const QrCodeBadge({
    super.key,
    this.qrCode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (qrCode == null || qrCode!.isEmpty) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.dashPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.qr_code_2,
          size: 20,
          color: AppColors.dashPrimary,
        ),
      ),
    );
  }
}
