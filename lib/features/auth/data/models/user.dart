/// Utilisateur — `UserSerializer` du backend.
class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String telephone;
  final String statut;

  const User({
    required this.id,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.telephone = '',
    this.statut = 'ACTIF',
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: (json['first_name'] as String?) ?? '',
        lastName: (json['last_name'] as String?) ?? '',
        telephone: (json['telephone'] as String?) ?? '',
        statut: (json['statut'] as String?) ?? 'ACTIF',
      );

  /// Forme serveur de l'utilisateur, telle que `UserSerializer` la renvoie.
  ///
  /// Necessaire pour memoriser la session dans le coffre du telephone et la
  /// rouvrir hors ligne a l'identique.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'telephone': telephone,
        'statut': statut,
      };

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? email : full;
  }

  String get initials {
    final parts = '$firstName $lastName'.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return email.isEmpty ? '?' : email[0].toUpperCase();
  }
}