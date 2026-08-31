import 'package:flutter/material.dart' show Color;

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/models/user.dart';
import 'role.dart';

/// Membre d'un business — `BusinessMemberSerializer`.
class Member {
  final String id;
  final User user;
  final Role? role;
  final String statut;
  final User? invitedBy;
  final DateTime? invitedAt;

  const Member({
    required this.id,
    required this.user,
    this.role,
    this.statut = 'INVITE',
    this.invitedBy,
    this.invitedAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        role: json['role'] == null
            ? null
            : Role.fromJson(json['role'] as Map<String, dynamic>),
        statut: (json['statut'] as String?) ?? 'INVITE',
        invitedBy: json['invited_by'] == null
            ? null
            : User.fromJson(json['invited_by'] as Map<String, dynamic>),
        invitedAt:
            DateTime.tryParse((json['invited_at'] as String?) ?? ''),
      );

  bool get isOwner => role?.nom == 'OWNER' && (role?.isSystem ?? false);
  bool get isActive => statut == 'ACTIF';
  bool get isInvited => statut == 'INVITE';
  bool get isBlocked => statut == 'BLOQUE';

  String get statutLabel {
    switch (statut) {
      case 'ACTIF':
        return 'Actif';
      case 'INVITE':
        return 'Invité';
      case 'BLOQUE':
        return 'Bloqué';
      default:
        return statut;
    }
  }

  Color get statutColor {
    switch (statut) {
      case 'ACTIF':
        return AppColors.successText;
      case 'INVITE':
        return AppColors.warningText;
      case 'BLOQUE':
        return AppColors.dangerText;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get statutBackground {
    switch (statut) {
      case 'ACTIF':
        return AppColors.success;
      case 'INVITE':
        return AppColors.warning;
      case 'BLOQUE':
        return AppColors.danger;
      default:
        return AppColors.inputBackground;
    }
  }
}