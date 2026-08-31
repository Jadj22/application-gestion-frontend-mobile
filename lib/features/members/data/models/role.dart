import 'permission.dart';

/// Rôle d'un business — `RoleSerializer` (inclut ses permissions).
class Role {
  final String id;
  final String nom;
  final String description;
  final bool isSystem;
  final List<Permission> permissions;

  const Role({
    required this.id,
    required this.nom,
    this.description = '',
    this.isSystem = false,
    this.permissions = const [],
  });

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json['id'] as String,
        nom: json['nom'] as String,
        description: (json['description'] as String?) ?? '',
        isSystem: (json['is_system'] as bool?) ?? false,
        permissions: ((json['permissions'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Permission.fromJson)
            .toList(),
      );

  bool hasPermission(String codename) =>
      permissions.any((p) => p.codename == codename);
}