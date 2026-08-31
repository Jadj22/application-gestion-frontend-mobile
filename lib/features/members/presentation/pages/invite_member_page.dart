import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/offline/offline_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/members_repository.dart';
import '../../data/models/role.dart';

/// Invitation d'un collaborateur (US-03) : email + rôle.
class InviteMemberPage extends StatefulWidget {
  const InviteMemberPage({super.key});

  @override
  State<InviteMemberPage> createState() => _InviteMemberPageState();
}

class _InviteMemberPageState extends State<InviteMemberPage> {
  final _formKey = GlobalKey<FormState>();
  late final MembersRepository _repository;
  late final Business _business;

  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  Role? _selectedRole;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MembersRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    final roles = context.read<SessionController>().roles;
    if (roles.isNotEmpty) {
      _selectedRole = roles
          .where((r) => r.nom == 'MEMBER')
          .firstOrNull ?? roles.first;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final member = await _repository.invite(
        _business.id,
        email: _emailController.text.trim(),
        roleId: _selectedRole?.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(member);
    } on OfflineUnsupportedException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkUnavailableException catch (e) {
      if (mounted) setState(() => _error = '${e.message}\nVérifiez votre connexion ou réessayez dans quelques secondes (serveur en démarrage).');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur inattendue: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = context.watch<SessionController>().roles;
    // Résolution par id : si la liste des rôles est rechargée (nouvelles
    // instances), on réutilise l'instance courante de la liste.
    final selected = _selectedRole == null
        ? null
        : roles.where((r) => r.id == _selectedRole!.id).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Inviter un collaborateur')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invitation', style: AppTextStyles.h1),
                const SizedBox(height: 4),
                Text(
                    'Le collaborateur recevra son accès via son adresse email.',
                    style: AppTextStyles.body),
                const SizedBox(height: 32),
                CustomInputField(
                  label: 'Adresse email *',
                  hint: 'collaborateur@exemple.com',
                  prefixIcon: Icons.mail_outline,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'L\'email est requis';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CustomInputField(
                        label: 'Prénom (optionnel)',
                        hint: 'Kossi',
                        prefixIcon: Icons.person_outline,
                        controller: _firstNameController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomInputField(
                        label: 'Nom (optionnel)',
                        hint: 'Agbo',
                        prefixIcon: Icons.person_outline,
                        controller: _lastNameController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('RÔLE', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                DropdownButtonFormField<Role>(
                  key: ObjectKey(roles),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Choisir un rôle',
                    prefixIcon:
                        Icon(Icons.badge_outlined, color: Colors.grey, size: 20),
                  ),
                  items: roles
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.nom,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (role) => setState(() => _selectedRole = role),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
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
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Inviter',
                  icon: Icons.send_outlined,
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}