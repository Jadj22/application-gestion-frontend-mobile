import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/maintenance_task.dart';

/// Page Calendrier de maintenance - Sprint 4.
/// Affiche les tâches planifiées dans un calendrier mensuel.
class MaintenanceCalendarScreen extends StatefulWidget {
  const MaintenanceCalendarScreen({super.key});

  @override
  State<MaintenanceCalendarScreen> createState() =>
      _MaintenanceCalendarScreenState();
}

class _MaintenanceCalendarScreenState extends State<MaintenanceCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<MaintenanceTaskModel> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
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
      final tasks = await repo.tasks(businessId);

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

  /// Récupère les tâches pour un jour donné.
  List<MaintenanceTaskModel> _getTasksForDay(DateTime day) {
    return _tasks.where((task) {
      if (task.createdAt == null) return false;
      final taskDate = DateTime.tryParse(task.createdAt!);
      if (taskDate == null) return false;
      return isSameDay(taskDate, day);
    }).toList();
  }

  /// Récupère les événements (markers) pour le calendrier.
  List<MaintenanceTaskModel> _getEventsForDay(DateTime day) {
    return _getTasksForDay(day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier maintenance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _buildBody(),
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

    return Column(
      children: [
        // Calendrier
        TableCalendar<MaintenanceTaskModel>(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          locale: 'fr_FR',
          calendarStyle: CalendarStyle(
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return const SizedBox.shrink();

              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(3).map((task) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _getTaskColor(task),
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),

        const Divider(),

        // Liste des tâches du jour sélectionné
        Expanded(
          child: _buildTasksList(),
        ),
      ],
    );
  }

  Widget _buildTasksList() {
    final tasks = _selectedDay != null ? _getTasksForDay(_selectedDay!) : [];

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucune tâche ce jour',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTaskColor(task).withValues(alpha: 0.2),
              child: Icon(
                _getTaskIcon(task),
                color: _getTaskColor(task),
              ),
            ),
            title: Text(task.procedureNom),
            subtitle: Text(task.itemNom),
            trailing: Chip(
              label: Text(task.statutLabel),
              backgroundColor: _getTaskColor(task).withValues(alpha: 0.1),
              labelStyle: TextStyle(color: _getTaskColor(task)),
            ),
            onTap: () {
              // TODO: Navigator vers le détail de la tâche
            },
          ),
        );
      },
    );
  }

  Color _getTaskColor(MaintenanceTaskModel task) {
    switch (task.statut) {
      case 'TERMINEE':
        return Colors.green;
      case 'EN_COURS':
        return Colors.orange;
      case 'PARTIELLE':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getTaskIcon(MaintenanceTaskModel task) {
    switch (task.statut) {
      case 'TERMINEE':
        return Icons.check_circle;
      case 'EN_COURS':
        return Icons.play_circle;
      case 'PARTIELLE':
        return Icons.pause_circle;
      default:
        return Icons.radio_button_unchecked;
    }
  }
}
