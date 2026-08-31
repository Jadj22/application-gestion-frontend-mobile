import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../core/config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/offline/offline_repository.dart';
import '../../../public/data/models/invoice_model.dart';

/// Repository pour les factures équipe (V4)
class InvoiceRepository {
  final ApiClient _api;
  final OfflineRepository _offline;

  InvoiceRepository(this._api, this._offline);

  /// Liste des factures avec filtres
  Future<PaginatedResult<InvoiceModel>> getTeamList({
    required String businessId,
    String? statut,
    String? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (statut != null) queryParams['statut'] = statut;
    if (type != null) queryParams['type'] = type;

    final endpoint = ApiEndpoints.businessInvoices(businessId);
    final path = '$endpoint?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final data = await _api.get(path) as Map<String, dynamic>;
    return PaginatedResult<InvoiceModel>(
      count: data['count'] as int,
      next: data['next'] as String?,
      previous: data['previous'] as String?,
      results: (data['results'] as List)
          .map((e) => InvoiceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Détail d'une facture
  Future<InvoiceModel> getTeamDetail({
    required String businessId,
    required String invoiceId,
  }) async {
    final decoded = await _api.get(
      ApiEndpoints.businessInvoice(businessId, invoiceId),
    );
    return InvoiceModel.fromJson(decoded as Map<String, dynamic>);
  }

  /// Crée une facture pour une réservation (avec idempotence)
  Future<InvoiceModel> create({
    required String businessId,
    required String reservationId,
    required String type,
    required double tvaTaux,
    required List<Map<String, dynamic>> lines,
  }) async {
    // Idempotence : même réservation + même type ne doit créer qu'une facture
    final idempotencyKey = 'inv_${businessId}_${reservationId}_${type}_$tvaTaux';
    try {
      final decoded = await _api.post(
        ApiEndpoints.businessInvoices(businessId),
        body: {
          'reservation_id': reservationId,
          'type': type,
          'tva_taux': tvaTaux.toStringAsFixed(2),
          'lignes': lines,
        },
        idempotencyKey: idempotencyKey,
      );
      return InvoiceModel.fromJson(decoded as Map<String, dynamic>);
    } on ApiException catch (e) {
      // Si le serveur signale que la réservation a déjà une facture (409),
      // on récupère la facture existante au lieu d'afficher une erreur 500
      if (e.statusCode == 409) {
        // Tente de retrouver la facture existante via la liste
        try {
          final list = await getTeamList(businessId: businessId, page: 1, pageSize: 100);
          final existing = list.results.where((inv) => inv.reservationId == reservationId).toList();
          if (existing.isNotEmpty) {
            return existing.first;
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Télécharge le PDF
  Future<Uint8List> downloadPdf({
    required String businessId,
    required String invoiceId,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${ApiEndpoints.businessInvoicePdf(businessId, invoiceId)}');
    final response = await http.get(url);
    if (response.statusCode >= 400) {
      throw Exception('Erreur téléchargement PDF: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// Marque comme envoyée
  Future<void> markSent({
    required String businessId,
    required String invoiceId,
  }) async {
    await _api.post(
      ApiEndpoints.businessInvoiceMarkSent(businessId, invoiceId),
    );
  }

  /// Marque comme payée
  Future<void> markPaid({
    required String businessId,
    required String invoiceId,
  }) async {
    await _api.post(
      ApiEndpoints.businessInvoiceMarkPaid(businessId, invoiceId),
    );
  }
}

/// Pagination générique
class PaginatedResult<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  const PaginatedResult({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });
}