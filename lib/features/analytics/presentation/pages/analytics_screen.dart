import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../maintenance/data/maintenance_repository.dart';
import '../../../auth/presentation/session_controller.dart';

/// Page Analytics - Sprint 5.
/// Affiche les statistiques avancées avec graphiques.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final businessId = session.currentBusinessId;
      if (businessId == null) throw Exception('Business non sélectionné');

      final repo = context.read<MaintenanceRepository>();
      final data = await repo.analytics(businessId);

      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
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
              onPressed: _loadAnalytics,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_data == null) {
      return const Center(child: Text('Aucune donnée'));
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Taux de complétion
            _buildCompletionCard(),
            const SizedBox(height: 16),

            // Coûts 30 jours
            _buildCostsCard(),
            const SizedBox(height: 16),

            // Tendance 30 jours
            _buildTrendChart(),
            const SizedBox(height: 16),

            // Articles les plus entretenus
            _buildTopItemsCard(),
            const SizedBox(height: 16),

            // Temps moyen par procédure
            _buildProcedureTimesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionCard() {
    final taux = (_data!['taux_completion'] as num?)?.toDouble() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Taux de complétion (30j)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: taux,
                          color: AppColors.primary,
                          title: '${taux.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PieChartSectionData(
                          value: 100 - taux,
                          color: Colors.grey.shade300,
                          title: '',
                        ),
                      ],
                      sectionsSpace: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${taux.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'des tâches terminées',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostsCard() {
    final couts = _data!['couts_30_jours'] as Map<String, dynamic>? ?? {};
    final mainOeuvre = (couts['main_oeuvre'] as num?)?.toDouble() ?? 0;
    final materiel = (couts['materiel'] as num?)?.toDouble() ?? 0;
    final total = (couts['total'] as num?)?.toDouble() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coûts de maintenance (30j)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCostItem('Main d\'oeuvre', mainOeuvre, Colors.blue),
                _buildCostItem('Matériel', materiel, Colors.orange),
                _buildCostItem('Total', total, AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(0)} F CFA',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    final tendance =
        (_data!['tendance_30_jours'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    if (tendance.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = tendance.asMap().entries.map((entry) {
      final count = (entry.value['count'] as num?)?.toDouble() ?? 0;
      return FlSpot(entry.key.toDouble(), count);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tendance des tâches (30j)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
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

  Widget _buildTopItemsCard() {
    final items =
        (_data!['articles_plus_entretenus'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Articles les plus entretenus',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...items.take(5).map((item) {
              final nom = item['nom'] as String? ?? 'Inconnu';
              final count = (item['count'] as num?)?.toInt() ?? 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.build, color: AppColors.primary, size: 20),
                ),
                title: Text(nom),
                trailing: Chip(
                  label: Text('$count'),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProcedureTimesCard() {
    final procedures =
        (_data!['temps_moyen_par_procedure'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    if (procedures.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Temps moyen par procédure',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...procedures.take(5).map((proc) {
              final nom = proc['procedure_nom'] as String? ?? 'Inconnu';
              final duree =
                  (proc['duree_moyenne_secondes'] as num?)?.toDouble() ?? 0;
              final minutes = (duree / 60).round();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.timer, color: Colors.blue, size: 20),
                ),
                title: Text(nom),
                trailing: Text(
                  '$minutes min',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
