import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../core/config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/invoice_model.dart';

/// Repository pour les factures publiques (V4) — client externe.
class PublicInvoiceRepository {
  final ApiClient _api;

  PublicInvoiceRepository(this._api);

  /// Récupère la facture d'une réservation (accès public via reservation_id).
  Future<InvoiceModel> getPublicInvoice({
    required String slug,
    required String reservationId,
  }) async {
    final decoded = await _api.get(
      ApiEndpoints.publicInvoice(slug, reservationId),
    );
    return InvoiceModel.fromJson(decoded as Map<String, dynamic>);
  }

  /// Télécharge le PDF de la facture (public).
  Future<Uint8List> downloadPdf({
    required String slug,
    required String reservationId,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${ApiEndpoints.publicInvoicePdf(slug, reservationId)}');
    final response = await http.get(url);
    if (response.statusCode >= 400) {
      throw Exception('Erreur téléchargement PDF: ${response.statusCode}');
    }
    return response.bodyBytes;
  }
}