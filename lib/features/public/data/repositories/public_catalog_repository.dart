import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/public_item_model.dart';

/// Repository pour le catalogue public (V1) — lecture seule, sans auth.
class PublicCatalogRepository {
  final ApiClient _api;

  PublicCatalogRepository(this._api);

  /// Liste les articles publiés d'un business avec disponibilité temps réel.
  ///
  /// [slug] : slug public du business
  /// [dateDebut], [dateFin] : optionnel, pour calculer la dispo sur une période
  Future<List<PublicItemModel>> getCatalog({
    required String slug,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{};
    if (dateDebut != null) {
      queryParams['date_debut'] = _isoDate(dateDebut);
    }
    if (dateFin != null) {
      queryParams['date_fin'] = _isoDate(dateFin);
    }

    final endpoint = ApiEndpoints.publicCatalog(slug);
    final path = queryParams.isEmpty
        ? endpoint
        : '$endpoint?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final decoded = await _api.get(path);

    final List<dynamic> data = decoded as List;
    return data.map((e) => PublicItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Disponibilité détaillée d'un article précis sur une période.
  Future<AvailabilityDetail> getAvailability({
    required String slug,
    required String itemId,
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    final path = '${ApiEndpoints.publicAvailability(slug, itemId)}?date_debut=${_isoDate(dateDebut)}&date_fin=${_isoDate(dateFin)}';
    final decoded = await _api.get(path);

    return AvailabilityDetail.fromJson(decoded as Map<String, dynamic>);
  }

  static String _isoDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}

/// Détail disponibilité (réponse de l'endpoint availability)
class AvailabilityDetail {
  final String itemId;
  final String itemNom;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int totalStock;
  final int disponible;
  final int reservesPendantPeriode;
  final int bookingRequestsPendantes;
  final int enEntretien;
  final int enStockPhysique;
  final bool peutReserver;
  final List<ReservationConflict> detailReservations;
  final List<BookingRequestConflict> detailBookingRequests;

  const AvailabilityDetail({
    required this.itemId,
    required this.itemNom,
    required this.dateDebut,
    required this.dateFin,
    required this.totalStock,
    required this.disponible,
    required this.reservesPendantPeriode,
    required this.bookingRequestsPendantes,
    required this.enEntretien,
    required this.enStockPhysique,
    required this.peutReserver,
    required this.detailReservations,
    required this.detailBookingRequests,
  });

  factory AvailabilityDetail.fromJson(Map<String, dynamic> json) {
    return AvailabilityDetail(
      itemId: json['item_id'] as String,
      itemNom: json['item_nom'] as String,
      dateDebut: DateTime.parse(json['date_debut'] as String),
      dateFin: DateTime.parse(json['date_fin'] as String),
      totalStock: (json['total_stock'] as num).toInt(),
      disponible: (json['disponible'] as num).toInt(),
      reservesPendantPeriode: (json['reserves_pendant_periode'] as num).toInt(),
      bookingRequestsPendantes: (json['booking_requests_pendantes'] as num?)?.toInt() ?? 0,
      enEntretien: (json['en_entretien'] as num).toInt(),
      enStockPhysique: (json['en_stock_physique'] as num).toInt(),
      peutReserver: json['peut_reserver'] as bool,
      detailReservations: (json['detail_reservations'] as List?)
              ?.map((e) => ReservationConflict.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      detailBookingRequests: (json['detail_booking_requests'] as List?)
              ?.map((e) => BookingRequestConflict.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ReservationConflict {
  final String id;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int quantite;
  final String statut;

  const ReservationConflict({
    required this.id,
    required this.dateDebut,
    required this.dateFin,
    required this.quantite,
    required this.statut,
  });

  factory ReservationConflict.fromJson(Map<String, dynamic> json) {
    return ReservationConflict(
      id: json['id'] as String,
      dateDebut: DateTime.parse(json['date_debut'] as String),
      dateFin: DateTime.parse(json['date_fin'] as String),
      quantite: (json['quantite'] as num).toInt(),
      statut: json['statut'] as String,
    );
  }
}

class BookingRequestConflict {
  final String id;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int quantite;
  final String statut;
  final String clientNom;

  const BookingRequestConflict({
    required this.id,
    required this.dateDebut,
    required this.dateFin,
    required this.quantite,
    required this.statut,
    required this.clientNom,
  });

  factory BookingRequestConflict.fromJson(Map<String, dynamic> json) {
    return BookingRequestConflict(
      id: json['id'] as String,
      dateDebut: DateTime.parse(json['date_debut'] as String),
      dateFin: DateTime.parse(json['date_fin'] as String),
      quantite: (json['quantite'] as num).toInt(),
      statut: json['statut'] as String,
      clientNom: json['client_nom'] as String,
    );
  }
}