/// Permission atomique — `PermissionSerializer` / `RoleSerializer.permissions`.
class Permission {
  final String codename;
  final String libelle;
  final String description;

  const Permission({
    required this.codename,
    required this.libelle,
    this.description = '',
  });

  factory Permission.fromJson(Map<String, dynamic> json) => Permission(
        codename: json['codename'] as String,
        libelle: (json['libelle'] as String?) ?? (json['codename'] as String),
        description: (json['description'] as String?) ?? '',
      );
}