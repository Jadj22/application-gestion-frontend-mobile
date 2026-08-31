/// Résultat d'une action sur une demande (accepter, refuser, contre-proposer)
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