import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/data/models/user.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/members_repository.dart';
import '../../data/models/member.dart';
import 'invite_member_page.dart';
import 'member_detail_page.dart';

/// Liste des membres du business (US-02) avec états loading/error/empty.
/// L'action d'invitation est masquée sans la permission member.invite (RM-19).
class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late final MembersRepository _repository;
  late final Business _business;

  bool _loading = true;
  String? _error;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _repository = context.read<MembersRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await _repository.members(_business.id);
      if (mounted) setState(() => _members = members);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final canInvite = session.can('member.invite');

    return Scaffold(
      appBar: AppBar(title: const Text('Membres')),
      floatingActionButton: canInvite
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _openInvite(),
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text('Inviter'),
            )
          : null,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Skeleton(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, _) => const SkeletonCard(
            radius: 20,
            child: SkeletonListItem(leadingCircle: true, leadingSize: 48),
          ),
        ),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (_members.isEmpty) {
      return _EmptyState(
        canInvite: context.read<SessionController>().can('member.invite'),
        onInvite: _openInvite,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final member = _members[index];
          return _MemberCard(
            member: member,
            onTap: () => _openDetail(member),
          );
        },
      ),
    );
  }

  Future<void> _openInvite() async {
    final invited = await Navigator.of(context).push<Member>(
      MaterialPageRoute(builder: (_) => const InviteMemberPage()),
    );
    if (invited != null && mounted) {
      setState(() => _members.insert(0, invited));
      _showSnack('Invitation envoyée à ${invited.user.email}');
    }
  }

  Future<void> _openDetail(Member member) async {
    final updated = await Navigator.of(context).push<Member>(
      MaterialPageRoute(builder: (_) => MemberDetailPage(member: member)),
    );
    if (updated != null && mounted) {
      final index = _members.indexWhere((m) => m.id == updated.id);
      if (index != -1) {
        setState(() => _members[index] = updated);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;

  const _MemberCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = member.user;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _Avatar(user: user),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName,
                        style: AppTextStyles.h2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: AppTextStyles.body,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip(
                          label: member.role?.nom ?? 'Aucun rôle',
                          background: AppColors.inputBackground,
                          foreground: AppColors.textPrimary,
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          label: member.statutLabel,
                          background: member.statutBackground,
                          foreground: member.statutColor,
                          icon: member.isActive
                              ? Icons.check_circle_outline
                              : member.isInvited
                                  ? Icons.schedule
                                  : Icons.block,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final User user;

  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        user.initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool canInvite;
  final VoidCallback onInvite;

  const _EmptyState({required this.canInvite, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_outlined, size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            Text('Aucun membre', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text('Invitez votre premier collaborateur.', style: AppTextStyles.body),
            if (canInvite) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: onInvite,
                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                  label: const Text('Inviter'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}