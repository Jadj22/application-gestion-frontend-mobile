import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/booking_request_model.dart';

/// Repository pour les demandes de location client (V2) — public + équipe.
class BookingRequestRepository {
  final ApiClient _api;

  BookingRequestRepository(this._api);

  // ========== PUBLIC (Client externe, sans auth) ==========

  /// Crée une demande de location (client externe).
  Future<BookingRequestCreateResult> createPublic({
    required String slug,
    required String itemId,
    required String clientNom,
    required String clientTelephone,
    required String clientEmail,
    required DateTime dateDebut,
    required DateTime dateFin,
    required int quantite,
    String message = '',
    String lieuNom = '',
    String lieuAdresse = '',
    String contactNom = '',
    String contactTelephone = '',
    String notesLivraison = '',
  }) async {
    final decoded = await _api.post(
      ApiEndpoints.publicBookingRequests(slug),
      body: {
        'item_id': itemId,
        'client_nom': clientNom,
        'client_telephone': clientTelephone,
        'client_email': clientEmail,
        'date_debut': _isoDate(dateDebut),
        'date_fin': _isoDate(dateFin),
        'quantite': quantite,
        if (message.isNotEmpty) 'message': message,
        if (lieuNom.isNotEmpty) 'lieu_nom': lieuNom,
        if (lieuAdresse.isNotEmpty) 'lieu_adresse': lieuAdresse,
        if (contactNom.isNotEmpty) 'contact_nom': contactNom,
        if (contactTelephone.isNotEmpty) 'contact_telephone': contactTelephone,
        if (notesLivraison.isNotEmpty) 'notes_livraison': notesLivraison,
      },
    );

    return BookingRequestCreateResult.fromJson(decoded as Map<String, dynamic>);
  }

  /// Récupère le détail d'une demande via token magique (client).
  Future<BookingRequestModel> getPublicDetail({
    required String slug,
    required String token,
  }) async {
    final decoded = await _api.get(
      ApiEndpoints.publicBookingRequestDetail(slug, token),
    );
    return BookingRequestModel.fromJson(decoded as Map<String, dynamic>);
  }

  /// Annule une demande par le client (si EN_ATTENTE ou ACCEPTEE).
  Future<void> cancelPublic({
    required String slug,
    required String token,
  }) async {
    await _api.post(
      ApiEndpoints.publicBookingRequestCancel(slug, token),
    );
  }

  /// Client accepte la contre-proposition → crée réservation.
  Future<BookingRequestCounterAcceptResult> acceptCounterPublic({
    required String slug,
    required String token,
  }) async {
    final decoded = await _api.post(
      ApiEndpoints.publicBookingRequestAcceptCounter(slug, token),
    );
    return BookingRequestCounterAcceptResult.fromJson(decoded as Map<String, dynamic>);
  }

  /// Client refuse la contre-proposition.
  Future<void> rejectCounterPublic({
    required String slug,
    required String token,
    required String motifRefus,
  }) async {
    await _api.post(
      ApiEndpoints.publicBookingRequestRejectCounter(slug, token),
      body: {'motif_refus': motifRefus},
    );
  }

  // ========== ÉQUIPE (Auth + perm RESERVATION_MANAGE/VIEW) ==========

  /// Liste les demandes pour l'équipe (filtres statut, dates).
  Future<PaginatedResult<BookingRequestModel>> getTeamList({
    required String businessId,
    String? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (statut != null) queryParams['statut'] = statut;
    if (dateDebut != null) queryParams['date_debut'] = _isoDate(dateDebut);
    if (dateFin != null) queryParams['date_fin'] = _isoDate(dateFin);

    final endpoint = ApiEndpoints.businessBookingRequests(businessId);
    final path = '$endpoint?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

    final data = await _api.get(path) as Map<String, dynamic>;
    return PaginatedResult<BookingRequestModel>(
      count: data['count'] as int,
      next: data['next'] as String?,
      previous: data['previous'] as String?,
      results: (data['results'] as List)
          .map((e) => BookingRequestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Détail d'une demande pour l'équipe.
  Future<BookingRequestModel> getTeamDetail({
    required String businessId,
    required String requestId,
  }) async {
    final decoded = await _api.get(
      ApiEndpoints.businessBookingRequest(businessId, requestId),
    );
    return BookingRequestModel.fromJson(decoded as Map<String, dynamic>);
  }

  /// Actions équipe : accepter, refuser, contre-proposer.
  Future<BookingRequestActionResult> actionTeam({
    required String businessId,
    required String requestId,
    required String action, // 'accepter', 'refuser', 'contre_proposer'
    String? motifRefus,
    DateTime? dateDebut,
    DateTime? dateFin,
    int? quantite,
    num? prix,
    String? message,
  }) async {
    final body = <String, dynamic>{'action': action};
    if (motifRefus != null) body['motif_refus'] = motifRefus;
    if (dateDebut != null) body['date_debut'] = _isoDate(dateDebut);
    if (dateFin != null) body['date_fin'] = _isoDate(dateFin);
    if (quantite != null) body['quantite'] = quantite;
    if (prix != null) body['prix'] = prix.toString();
    if (message != null) body['message'] = message;

    final decoded = await _api.post(
      ApiEndpoints.businessBookingRequestAction(businessId, requestId),
      body: body,
    );

    return BookingRequestActionResult.fromJson(decoded as Map<String, dynamic>);
  }

  static String _isoDate(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Résultat création demande publique
class BookingRequestCreateResult {
  final String id;
  final String accessToken;
  final DateTime expiresAt;
  final String detailUrl;
  final String message;

  const BookingRequestCreateResult({
    required this.id,
    required this.accessToken,
    required this.expiresAt,
    required this.detailUrl,
    required this.message,
  });

  factory BookingRequestCreateResult.fromJson(Map<String, dynamic> json) {
    return BookingRequestCreateResult(
      id: json['id'] as String,
      accessToken: json['access_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      detailUrl: json['detail_url'] as String,
      message: json['message'] as String,
    );
  }
}

/// Résultat acceptation contre-proposition par client
class BookingRequestCounterAcceptResult {
  final String message;
  final String reservationId;
  final Map<String, dynamic> reservation;

  const BookingRequestCounterAcceptResult({
    required this.message,
    required this.reservationId,
    required this.reservation,
  });

  factory BookingRequestCounterAcceptResult.fromJson(Map<String, dynamic> json) {
    return BookingRequestCounterAcceptResult(
      message: json['message'] as String,
      reservationId: json['reservation_id'] as String,
      reservation: json['reservation'] as Map<String, dynamic>,
    );
  }
}

/// Résultat action équipe
class BookingRequestActionResult {
  final String message;
  final String? reservationId;
  final Map<String, dynamic>? reservation;
  final Map<String, dynamic>? contreProposition;

  const BookingRequestActionResult({
    required this.message,
    this.reservationId,
    this.reservation,
    this.contreProposition,
  });

  factory BookingRequestActionResult.fromJson(Map<String, dynamic> json) {
    return BookingRequestActionResult(
      message: json['message'] as String,
      reservationId: json['reservation_id'] as String?,
      reservation: json['reservation'] as Map<String, dynamic>?,
      contreProposition: json['contre_proposition'] as Map<String, dynamic>?,
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