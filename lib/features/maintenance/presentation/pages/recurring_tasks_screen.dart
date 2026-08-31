import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/recurring_task.dart';

/// Page de gestion des tâches récurrentes - Sprint 3.
/// Permet de créer et gérer les maintenances planifiées automatiques.
class RecurringTasksScreen extends StatefulWidget {
  const RecurringTasksScreen({super.key});

  @override
  State<RecurringTasksScreen> createState() => _RecurringTasksScreenState();
}

class _RecurringTasksScreenState extends State<RecurringTasksScreen> {
  List<RecurringTaskModel> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) throw Exception('Business non sélectionné');

      final repo = context.read<MaintenanceRepository>();
      final tasks = await repo.recurringTasks(businessId);

      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleTask(RecurringTaskModel task) async {
    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) return;

      final repo = context.read<MaintenanceRepository>();
      await repo.updateRecurringTask(
        businessId,
        task.id,
        estActif: !task.estActif,
      );

      _loadTasks();
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

  Future<void> _deleteTask(RecurringTaskModel task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la tâche récurrente ?'),
        content: Text(
          'La planification "${task.procedureNom}" sera supprimée. '
          'Les tâches déjà créées ne seront pas affectées.',
        ),
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
      await repo.deleteRecurringTask(businessId, task.id);

      _loadTasks();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tâche récurrente supprimée')),
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
      builder: (context) => _CreateRecurringTaskSheet(
        onCreated: _loadTasks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tâches récurrentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
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
              onPressed: _loadTasks,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.repeat, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucune tâche récurrente',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez des maintenances automatiques',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return _RecurringTaskCard(
            task: task,
            onToggle: () => _toggleTask(task),
            onDelete: () => _deleteTask(task),
          );
        },
      ),
    );
  }
}

class _RecurringTaskCard extends StatelessWidget {
  final RecurringTaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RecurringTaskCard({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.procedureNom,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (task.itemNom != null)
                        Text(
                          'Article: ${task.itemNom}',
                          style: TextStyle(color: Colors.grey.shade600),
                        )
                      else if (task.categoryNom != null)
                        Text(
                          'Catégorie: ${task.categoryNom}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: task.estActif,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.repeat,
                  label: task.frequenceLabel,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: _formatDate(task.prochaineExecution),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Non définie';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet de création d'une tâche récurrente.
class _CreateRecurringTaskSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateRecurringTaskSheet({required this.onCreated});

  @override
  State<_CreateRecurringTaskSheet> createState() =>
      _CreateRecurringTaskSheetState();
}

class _CreateRecurringTaskSheetState extends State<_CreateRecurringTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  String? _selectedProcedureId;
  String? _selectedItemId;
  String? _selectedCategoryId;
  int _frequenceJours = 7;
  DateTime _prochaineExecution = DateTime.now().add(const Duration(days: 1));

  // Options de fréquence prédéfinies
  final List<Map<String, dynamic>> _frequenceOptions = [
    {'label': 'Quotidien', 'jours': 1},
    {'label': 'Hebdomadaire', 'jours': 7},
    {'label': 'Bi-mensuel', 'jours': 14},
    {'label': 'Mensuel', 'jours': 30},
    {'label': 'Trimestriel', 'jours': 90},
    {'label': 'Annuel', 'jours': 365},
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProcedureId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une procédure')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) throw Exception('Business non sélectionné');

      final repo = context.read<MaintenanceRepository>();
      await repo.createRecurringTask(
        businessId,
        procedureId: _selectedProcedureId!,
        frequenceJours: _frequenceJours,
        prochaineExecution: _prochaineExecution.toIso8601String(),
        itemId: _selectedItemId,
        categoryId: _selectedCategoryId,
      );

      widget.onCreated();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tâche récurrente créée')),
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

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _prochaineExecution,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _prochaineExecution = date);
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
                    'Nouvelle tâche récurrente',
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

              // TODO: Dropdown pour sélectionner la procédure
              // Nécessite de charger la liste des procédures depuis l'API
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Text(
                      'Sélectionner une procédure',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Fréquence
              const Text(
                'Fréquence',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _frequenceOptions.map((option) {
                  final isSelected = _frequenceJours == option['jours'];
                  return ChoiceChip(
                    label: Text(option['label']),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _frequenceJours = option['jours']);
                      }
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Date de première exécution
              const Text(
                'Première exécution',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Text(
                        '${_prochaineExecution.day}/${_prochaineExecution.month}/${_prochaineExecution.year}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton de création
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Créer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
