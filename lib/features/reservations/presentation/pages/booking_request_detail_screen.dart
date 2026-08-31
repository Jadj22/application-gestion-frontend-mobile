import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/logi_event_shell.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/repositories/booking_request_repository.dart';
import '../../data/models/booking_request_model.dart';
import '../../data/models/booking_request_action_result.dart';

/// Détail d'une demande de réservation pour l'équipe
class BookingRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const BookingRequestDetailScreen({super.key, required this.requestId});

  @override
  State<BookingRequestDetailScreen> createState() => _BookingRequestDetailScreenState();
}

class _BookingRequestDetailScreenState extends State<BookingRequestDetailScreen> {
  late final BookingRequestRepository _repository;
  late final Business _business;

  BookingRequestModel? _request;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<BookingRequestRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await _repository.getTeamDetail(
        businessId: _business.id,
        requestId: widget.requestId,
      );
      if (mounted) setState(() => _request = request);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(String action, {String? motifRefus, String? dateDebut, String? dateFin, int? quantite, double? prix, String? message}) async {
    if (_request == null) return;
    setState(() => _working = true);
    try {
      final result = await _repository.actionTeam(
        businessId: _business.id,
        requestId: _request!.id,
        action: action,
        motifRefus: motifRefus,
        dateDebut: dateDebut,
        dateFin: dateFin,
        quantite: quantite,
        prix: prix,
        message: message,
      );
      if (!mounted) return;
      
      if (result.reservationId != null) {
        // Accepter -> réservation créée
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demande acceptée. Réservation créée (${result.reservationId})'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (action == 'refuser') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande refusée'), backgroundColor: Colors.red),
        );
      } else if (action == 'contre_proposer') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contre-proposition envoyée: ${result.message}'), backgroundColor: Colors.orange),
        );
      }
      
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showAcceptDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accepter la demande ?'),
        content: const Text('Cela créera une réservation confirmée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _runAction('accepter');
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showRefuseDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refuser la demande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Motif du refus (obligatoire) :'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Indiquez le motif du refus...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final motif = controller.text.trim();
              if (motif.isEmpty) return;
              Navigator.of(dialogContext).pop();
              _runAction('refuser', motifRefus: motif);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }

  void _showCounterProposalDialog() {
    final dateDebutController = TextEditingController(
      text: _request!.dateDebut.split('T').first,
    );
    final dateFinController = TextEditingController(
      text: _request!.dateFin.split('T').first,
    );
    final quantiteController = TextEditingController(text: _request!.quantite.toString());
    final prixController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contre-proposition'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Modifiez les éléments souhaités :'),
              const SizedBox(height: 16),
              TextField(
                controller: dateDebutController,
                decoration: const InputDecoration(
                  labelText: 'Date début (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: dialogContext,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: DateTime.tryParse(dateDebutController.text) ?? DateTime.now(),
                  );
                  if (date != null) {
                    dateDebutController.text = date.toIso8601String().split('T').first;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateFinController,
                decoration: const InputDecoration(
                  labelText: 'Date fin (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: dialogContext,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: DateTime.tryParse(dateFinController.text) ?? DateTime.now(),
                  );
                  if (date != null) {
                    dateFinController.text = date.toIso8601String().split('T').first;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantiteController,
                decoration: const InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prixController,
                decoration: const InputDecoration(
                  labelText: 'Prix unitaire (optionnel)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _runAction(
                'contre_proposer',
                dateDebut: dateDebutController.text,
                dateFin: dateFinController.text,
                quantite: int.tryParse(quantiteController.text),
                prix: double.tryParse(prixController.text),
                message: messageController.text.trim().isEmpty ? null : messageController.text.trim(),
              );
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = _request;

    return LogiEventShell(
      navIndex: 3,
      showNavigation: false,
      pageTitle: 'Détail Demande',
      body: SafeArea(
        child: _loading
            ? _buildLoadingSkeleton()
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : request == null
                    ? const Center(child: Text('Demande introuvable'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(request!),
                            const SizedBox(height: 16),
                            _buildClientInfo(request!),
                            const SizedBox(height: 16),
                            _buildDatesQuantite(request!),
                            const SizedBox(height: 16),
                            _buildLocation(request!),
                            const SizedBox(height: 16),
                            _buildCounterProposal(request!),
                            const SizedBox(height: 16),
                            _buildActions(request!),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Skeleton(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          children: List.generate(5, (index) => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SkeletonCard(
              padding: EdgeInsets.all(16),
              radius: 16,
              child: SkeletonListItem(),
            ),
          )),
        ),
      ),
    );
  }

  Widget _buildHeader(BookingRequestModel request) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                _statusIconOf(request.statut),
                size: 24,
                color: _statusColorOf(request.statut),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.itemNom,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColorOf(request.statut).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      request.statutDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColorOf(request.statut),
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

  Widget _buildClientInfo(BookingRequestModel request) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            _InfoRow(label: 'Nom', value: request.clientNom),
            if (request.clientEmail.isNotEmpty)
              _InfoRow(label: 'Email', value: request.clientEmail),
            if (request.clientTelephone.isNotEmpty)
              _InfoRow(label: 'Téléphone', value: request.clientTelephone),
            if (request.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Message', value: request.message),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatesQuantite(BookingRequestModel request) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dates & Quantité', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoColumn(
                    label: 'Début',
                    value: _formatDate(request.dateDebut),
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    label: 'Fin',
                    value: _formatDate(request.dateFin),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Quantité',
              value: '${request.quantite} ${request.itemUnite}',
            ),
            if (request.lieuNom.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Lieu', value: request.lieuNom),
            ],
            if (request.lieuAdresse.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Adresse', value: request.lieuAdresse),
            ],
            if (request.contactNom.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Contact sur place', value: request.contactNom),
            ],
            if (request.contactTelephone.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Téléphone contact', value: request.contactTelephone),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocation(BookingRequestModel request) {
    if (request.lieuNom.isEmpty && request.lieuAdresse.isEmpty &&
        request.contactNom.isEmpty && request.contactTelephone.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lieu & Contact', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 12),
            if (request.lieuNom.isNotEmpty)
              _InfoRow(label: 'Lieu', value: request.lieuNom),
            if (request.lieuAdresse.isNotEmpty)
              _InfoRow(label: 'Adresse', value: request.lieuAdresse),
            if (request.contactNom.isNotEmpty)
              _InfoRow(label: 'Contact', value: request.contactNom),
            if (request.contactTelephone.isNotEmpty)
              _InfoRow(label: 'Téléphone', value: request.contactTelephone),
            if (request.notesLivraison.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Notes livraison', value: request.notesLivraison),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCounterProposal(BookingRequestModel request) {
    final contre = request.contreProposition;
    if (contre == null) return const SizedBox.shrink();

    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Contre-proposition',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contre['date_debut'] != null && contre['date_fin'] != null)
              _InfoRow(
                label: 'Période proposée',
                value: '${contre['date_debut']} → ${contre['date_fin']}',
              ),
            if (contre['quantite'] != null)
              _InfoRow(
                label: 'Quantité proposée',
                value: contre['quantite'].toString(),
              ),
            if (contre['prix'] != null)
              _InfoRow(
                label: 'Prix unitaire',
                value: '${contre['prix']} F CFA',
              ),
            if (contre['message'] != null && contre['message'].isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Message', value: contre['message']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BookingRequestModel request) {
    final canProcess = request.statut == 'EN_ATTENTE';

    if (!canProcess) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Cette demande ne peut plus être traitée (statut : ${request.statutDisplay}).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Actions', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _showRefuseDialog,
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Refuser', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _showCounterProposalDialog,
                    icon: const Icon(Icons.sync),
                    label: const Text('Contre-proposer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _working ? null : _showAcceptDialog,
              icon: const Icon(Icons.check_circle),
              label: const Text('Accepter la demande'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColorOf(String statut) {
    switch (statut) {
      case 'EN_ATTENTE':
        return AppColors.kpiAmber;
      case 'ACCEPTEE':
        return AppColors.kpiBlue;
      case 'REFUSEE':
        return AppColors.kpiRose;
      case 'CONVERTIE':
        return AppColors.kpiGreen;
      case 'EXPIREE':
        return Colors.grey;
      default:
        return AppColors.dashOutline;
    }
  }

  IconData _statusIconOf(String statut) {
    switch (statut) {
      case 'EN_ATTENTE':
        return Icons.schedule;
      case 'ACCEPTEE':
        return Icons.check_circle;
      case 'REFUSEE':
        return Icons.cancel;
      case 'CONVERTIE':
        return Icons.assignment_turned_in;
      case 'EXPIREE':
        return Icons.access_time;
      default:
        return Icons.help_outline;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.dangerText),
            const SizedBox(height: 16),
            Text('Erreur de chargement', style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}