import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../data/models/booking_request_model.dart';

/// Repository pour les demandes de réservation côté équipe (authentifié)
class BookingRequestRepository {
  final ApiClient _api;

  BookingRequestRepository(this._api);

  /// Liste les demandes pour un business avec filtres optionnels
  Future<PaginatedResult<BookingRequestModel>> getTeamList({
    required String businessId,
    String? statut,
    String? dateDebut,
    String? dateFin,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (statut != null && statut.isNotEmpty) queryParams['statut'] = statut;
    if (dateDebut != null && dateDebut.isNotEmpty) queryParams['date_debut'] = dateDebut;
    if (dateFin != null && dateFin.isNotEmpty) queryParams['date_fin'] = dateFin;

    final endpoint = ApiEndpoints.businessBookingRequests(businessId);
    final path = '$endpoint?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final data = await _api.get(path) as Map<String, dynamic>;

    return PaginatedResult<BookingRequestModel>(
      count: data['count'] as int? ?? 0,
      next: data['next'] as String?,
      previous: data['previous'] as String?,
      results: (data['results'] as List? ?? [])
          .map((e) => BookingRequestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Détail d'une demande pour l'équipe
  Future<BookingRequestModel> getTeamDetail({
    required String businessId,
    required String requestId,
  }) async {
    final decoded = await _api.get(
      ApiEndpoints.businessBookingRequest(businessId, requestId),
    );
    return BookingRequestModel.fromJson(decoded as Map<String, dynamic>);
  }

  /// Action sur une demande (accepter, refuser, contre-proposer)
  Future<BookingRequestActionResult> actionTeam({
    required String businessId,
    required String requestId,
    required String action,
    String? motifRefus,
    String? dateDebut,
    String? dateFin,
    int? quantite,
    double? prix,
    String? message,
  }) async {
    final body = <String, dynamic>{
      'action': action,
    };
    if (motifRefus != null) body['motif_refus'] = motifRefus;
    if (dateDebut != null) body['date_debut'] = dateDebut;
    if (dateFin != null) body['date_fin'] = dateFin;
    if (quantite != null) body['quantite'] = quantite;
    if (prix != null) body['prix'] = prix;
    if (message != null && message.isNotEmpty) body['message'] = message;

    final decoded = await _api.post(
      ApiEndpoints.businessBookingRequestAction(businessId, requestId),
      body: body,
    );
    return BookingRequestActionResult.fromJson(decoded as Map<String, dynamic>);
  }
}

/// Résultat paginé générique
class PaginatedResult<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  PaginatedResult({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });
}

/// Résultat d'une action sur une demande
class BookingRequestActionResult {
  final String message;
  final String? reservationId;
  final Map<String, dynamic>? contreProposition;

  BookingRequestActionResult({
    required this.message,
    this.reservationId,
    this.contreProposition,
  });

  factory BookingRequestActionResult.fromJson(Map<String, dynamic> json) {
    return BookingRequestActionResult(
      message: json['message'] as String? ?? '',
      reservationId: json['reservation_id'] as String?,
      contreProposition: json['contre_proposition'] as Map<String, dynamic>?,
    );
  }
}