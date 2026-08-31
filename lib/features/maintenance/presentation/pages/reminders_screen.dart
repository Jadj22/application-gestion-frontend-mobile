import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/reminder.dart';

/// Page de gestion des rappels - Sprint 3.
/// Affiche la liste des rappels planifiés et permet d'en créer.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<ReminderModel> _reminders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) throw Exception('Business non sélectionné');

      final repo = context.read<MaintenanceRepository>();
      final reminders = await repo.reminders(businessId);

      setState(() {
        _reminders = reminders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteReminder(ReminderModel reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le rappel ?'),
        content: Text('Le rappel "${reminder.message}" sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) return;

      final repo = context.read<MaintenanceRepository>();
      await repo.deleteReminder(businessId, reminder.id);

      _loadReminders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rappel supprimé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateReminderSheet(
        onCreated: _loadReminders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rappels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReminders,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.alarm_add),
        label: const Text('Nouveau rappel'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Erreur: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReminders,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    // Séparer les rappels envoyés des non envoyés
    final pending = _reminders.where((r) => !r.envoye).toList();
    final sent = _reminders.where((r) => r.envoye).toList();

    if (_reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucun rappel',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez un rappel pour ne rien oublier',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pending.isNotEmpty) ...[
            Text(
              'À venir',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            ...pending.map((reminder) => _ReminderCard(
                  reminder: reminder,
                  onDelete: () => _deleteReminder(reminder),
                )),
            const SizedBox(height: 24),
          ],
          if (sent.isNotEmpty) ...[
            Text(
              'Envoyés',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            ...sent.map((reminder) => _ReminderCard(
                  reminder: reminder,
                  onDelete: () => _deleteReminder(reminder),
                )),
          ],
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPast =
        DateTime.tryParse(reminder.rappelA)?.isBefore(DateTime.now()) == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: reminder.envoye
              ? Colors.green.withValues(alpha: 0.1)
              : isPast
                  ? Colors.orange.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.1),
          child: Icon(
            reminder.envoye
                ? Icons.check
                : isPast
                    ? Icons.warning
                    : Icons.alarm,
            color: reminder.envoye
                ? Colors.green
                : isPast
                    ? Colors.orange
                    : AppColors.primary,
          ),
        ),
        title: Text(
          reminder.message,
          style: TextStyle(
            decoration: reminder.envoye ? TextDecoration.lineThrough : null,
            color: reminder.envoye ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(reminder.rappelA),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (reminder.taskId != null || reminder.itemId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  reminder.taskId != null
                      ? 'Lié à une tâche'
                      : 'Lié à un article',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.red.shade300,
          onPressed: onDelete,
        ),
        isThreeLine: reminder.taskId != null || reminder.itemId != null,
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'Non défini';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    String dateLabel;
    if (dateOnly == today) {
      dateLabel = "Aujourd'hui";
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      dateLabel = 'Demain';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Hier';
    } else {
      dateLabel = '${date.day}/${date.month}/${date.year}';
    }

    return '$dateLabel à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Sheet de création d'un rappel.
class _CreateReminderSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateReminderSheet({required this.onCreated});

  @override
  State<_CreateReminderSheet> createState() => _CreateReminderSheetState();
}

class _CreateReminderSheetState extends State<_CreateReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _loading = false;

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Raccourcis de temps
  final List<Map<String, dynamic>> _quickOptions = [
    {'label': 'Dans 1h', 'duration': const Duration(hours: 1)},
    {'label': 'Dans 3h', 'duration': const Duration(hours: 3)},
    {'label': 'Demain 9h', 'duration': null, 'hour': 9},
    {'label': 'Dans 1 semaine', 'duration': const Duration(days: 7)},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _applyQuickOption(Map<String, dynamic> option) {
    final now = DateTime.now();
    DateTime newDate;

    if (option['duration'] != null) {
      newDate = now.add(option['duration'] as Duration);
    } else {
      // Demain à une heure spécifique
      newDate = DateTime(
        now.year,
        now.month,
        now.day + 1,
        option['hour'] as int,
      );
    }

    setState(() {
      _selectedDate = newDate;
      _selectedTime = TimeOfDay(hour: newDate.hour, minute: newDate.minute);
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) throw Exception('Business non sélectionné');

      final repo = context.read<MaintenanceRepository>();
      await repo.createReminder(
        businessId,
        userId: session.user?.id ?? '',
        message: _messageController.text.trim(),
        rappelA: _selectedDate.toIso8601String(),
      );

      widget.onCreated();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rappel créé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Nouveau rappel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Message
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message du rappel',
                  hintText: 'Ex: Vérifier la pompe à eau',
                  prefixIcon: Icon(Icons.message_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLength: 255,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Entrez un message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Raccourcis
              const Text(
                'Rappeler',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickOptions.map((option) {
                  return ActionChip(
                    label: Text(option['label']),
                    onPressed: () => _applyQuickOption(option),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Date et heure personnalisées
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: Colors.grey.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time,
                                color: Colors.grey.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Bouton de création
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.alarm_add),
                  label: const Text('Créer le rappel'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
