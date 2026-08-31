/// Utilisateur simplifié pour l'affichage dans les tâches.
class UserSimple {
  final String id;
  final String email;
  final String? nom;

  const UserSimple({
    required this.id,
    required this.email,
    this.nom,
  });

  /// Nom d'affichage : nom ou partie avant @ de l'email.
  String get displayName {
    if (nom != null && nom!.isNotEmpty) {
      return nom!;
    }
    return email.split('@').first;
  }

  /// Initiales pour l'avatar (2 lettres max).
  String get initiales {
    final name = displayName;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory UserSimple.fromJson(Map<String, dynamic> json) => UserSimple(
        id: json['id'] as String,
        email: (json['email'] as String?) ?? '',
        nom: json['nom'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        if (nom != null) 'nom': nom,
      };
}
