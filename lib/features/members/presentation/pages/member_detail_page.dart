import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/members_repository.dart';
import '../../data/models/member.dart';
import '../../data/models/permission.dart';
import '../../data/models/role.dart';

/// Fiche membre (US-02/US-03) : rôle attribué, permissions du rôle,
/// changement de rôle/statut et retrait — chaque action contrôlée par les
/// permissions de l'utilisateur courant (RM-17, RM-19 ; le backend reste
/// l'autorité de sécurité).
class MemberDetailPage extends StatefulWidget {
  final Member member;

  const MemberDetailPage({super.key, required this.member});

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  late final MembersRepository _repository;
  late final Business _business;

  Member? _member;
  Role? _selectedRole;
  bool _savingRole = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MembersRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _member = widget.member;
    _selectedRole = widget.member.role;
  }

  bool get _canChangeRole =>
      context.read<SessionController>().can('member.role_update');
  bool get _canRemove =>
      context.read<SessionController>().can('member.remove');

  Future<void> _saveRole(Role role) async {
    setState(() {
      _savingRole = true;
      _error = null;
    });
    try {
      final updated = await _repository.update(
        _business.id,
        _member!.id,
        roleId: role.id,
      );
      if (mounted) {
        setState(() {
          _member = updated;
          _selectedRole = updated.role;
        });
        _showSnack('Rôle attribué : ${updated.role?.nom}');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _savingRole = false);
    }
  }

  Future<void> _toggleBlock() async {
    final member = _member!;
    final block = !member.isBlocked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(block ? 'Bloquer le membre' : 'Réactiver le membre'),
        content: Text(block
            ? 'Bloquer ${member.user.displayName} ? Il ne pourra plus '
                'accéder au business.'
            : 'Réactiver ${member.user.displayName} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(block ? 'Bloquer' : 'Réactiver',
                style: const TextStyle(color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _error = null);
    try {
      final updated = await _repository.update(
        _business.id,
        member.id,
        statut: block ? 'BLOQUE' : 'ACTIF',
      );
      if (mounted) {
        setState(() => _member = updated);
        _showSnack(block ? 'Membre bloqué' : 'Membre réactivé');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _remove() async {
    final member = _member!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: Text('Retirer ${member.user.displayName} du business ? '
            'Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retirer',
                style: TextStyle(color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await _repository.remove(_business.id, member.id);
      if (mounted) Navigator.of(context).pop(member);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final member = _member!;
    final roles = context.watch<SessionController>().roles;
    // Résolution par id : widget.member.role provient de GET /members/
    // (instances différentes de celles de session.roles).
    final selectedRole = _selectedRole == null
        ? null
        : roles.where((r) => r.id == _selectedRole!.id).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Membre')),
      body: _deleting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Header(member: member),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RÔLE', style: AppTextStyles.fieldLabel),
                        const SizedBox(height: 12),
                        if (member.isOwner)
                          _SystemRoleNotice(member: member)
                        else if (_canChangeRole)
                          DropdownButtonFormField<Role>(
                            key: ObjectKey(roles),
                            initialValue: selectedRole,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              hintText: 'Attribuer un rôle',
                              prefixIcon: Icon(Icons.badge_outlined,
                                  color: Colors.grey, size: 20),
                            ),
                            items: roles
                                .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role.nom,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: _savingRole
                                ? null
                                : (role) {
                                    if (role != null && role.id != _selectedRole?.id) {
                                      _selectedRole = role;
                                      _saveRole(role);
                                    }
                                  },
                          )
                        else
                          _StaticRole(role: member.role),
                        if (_savingRole) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.dangerText, fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _PermissionsCard(role: member.role),
                if (_canRemove && !member.isOwner) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _toggleBlock,
                    icon: Icon(
                      member.isBlocked ? Icons.lock_open : Icons.block,
                      size: 20,
                      color: AppColors.warningText,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.warning),
                      foregroundColor: AppColors.warningText,
                    ),
                    label: Text(member.isBlocked ? 'Réactiver' : 'Bloquer'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _remove,
                    icon: const Icon(Icons.person_remove_outlined,
                        size: 20, color: AppColors.dangerText),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      foregroundColor: AppColors.dangerText,
                    ),
                    label: const Text('Retirer du business'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final Member member;

  const _Header({required this.member});

  @override
  Widget build(BuildContext context) {
    final user = member.user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: AppTextStyles.h2),
                  const SizedBox(height: 2),
                  Text(user.email, style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: member.statutBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      member.statutLabel,
                      style: TextStyle(
                        color: member.statutColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemRoleNotice extends StatelessWidget {
  final Member member;

  const _SystemRoleNotice({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Propriétaire (${member.role?.nom}) — rôle système '
              'protégé, non modifiable (RM-17).',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticRole extends StatelessWidget {
  final Role? role;

  const _StaticRole({this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            role?.nom ?? 'Aucun rôle',
            style: AppTextStyles.h2,
          ),
        ],
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  final Role? role;

  const _PermissionsCard({this.role});

  @override
  Widget build(BuildContext context) {
    final permissions = role?.permissions ?? const <Permission>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PERMISSIONS DU RÔLE (${role?.nom ?? '—'})',
                style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            if (permissions.isEmpty)
              Text('Aucune permission définie.', style: AppTextStyles.body)
            else
              ...permissions.map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 18, color: AppColors.successText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.libelle,
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}