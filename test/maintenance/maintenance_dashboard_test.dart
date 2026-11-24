import 'package:dodome/features/items/data/models/catalog_item.dart';
import 'package:dodome/features/maintenance/data/models/maintenance_task.dart';
import 'package:dodome/features/maintenance/presentation/widgets/maintenance_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('planifier un article sans tâche active', (tester) async {
    CatalogItemModel? plannedItem;
    final catalogItems = [
      const CatalogItemModel(
        id: 'damaged-item',
        nom: 'Chaise abîmée',
        endommages: 2,
      ),
      const CatalogItemModel(
        id: 'active-item',
        nom: 'Table en entretien',
        entretienRequis: true,
      ),
    ];
    final tasks = [
      const MaintenanceTaskModel(
        id: 'active-task',
        itemId: 'active-item',
        itemNom: 'Table en entretien',
        procedureNom: 'Contrôle',
        statut: 'EN_COURS',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaintenanceDashboard(
            tasks: tasks,
            catalogItems: catalogItems,
            onPlanItem: (item) => plannedItem = item,
          ),
        ),
      ),
    );

    expect(find.text('À planifier'), findsOneWidget);
    expect(find.text('Chaise abîmée'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Planifier'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Planifier'));
    await tester.pump();

    expect(plannedItem?.id, 'damaged-item');
  });
}
