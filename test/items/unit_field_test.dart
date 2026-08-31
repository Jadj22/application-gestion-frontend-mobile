import 'package:dodome/features/items/presentation/widgets/unit_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Régression : l'ajout d'une unité personnalisée faisait planter l'écran de
/// création d'article.
void main() {
  Widget hote({
    required TextEditingController controller,
    List<String> custom = const [],
    Future<void> Function(String)? onCreate,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UnitField(
              controller: controller,
              customUnits: custom,
              onCreate: onCreate ?? (_) async {},
            ),
          ),
        ),
      );

  testWidgets('le champ s\'affiche sans unité choisie', (tester) async {
    await tester.pumpWidget(hote(controller: TextEditingController()));
    expect(find.byType(UnitField), findsOneWidget);
  });

  testWidgets('une unité standard déjà saisie s\'affiche', (tester) async {
    await tester.pumpWidget(
      hote(controller: TextEditingController(text: 'kg')),
    );
    expect(find.text('Kilogramme (kg)'), findsWidgets);
  });

  testWidgets('une unité personnalisée déjà saisie s\'affiche', (tester) async {
    // Cas d'un article existant dont l'unité ne figure dans aucune liste :
    // elle doit être proposée plutôt que perdue.
    await tester.pumpWidget(
      hote(controller: TextEditingController(text: 'botte')),
    );
    expect(find.text('botte'), findsWidgets);
  });

  testWidgets('ajouter une unité personnalisée ne fait pas planter',
      (tester) async {
    final controller = TextEditingController();
    var creee = '';

    await tester.pumpWidget(
      hote(
        controller: controller,
        onCreate: (unite) async => creee = unite,
      ),
    );

    await tester.tap(find.text('Ajouter une unité'));
    await tester.pumpAndSettle();

    // Saisir la nouvelle unité et valider.
    await tester.enterText(find.byType(TextField).last, 'botte');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(creee, 'botte');
    expect(controller.text, 'botte');
    expect(tester.takeException(), isNull);
  });

  testWidgets("saisir une unité déjà standard ne fait pas planter le menu",
      (tester) async {
    // C'était le crash. « sac » figure déjà dans la liste standard ; proposé
    // en plus comme unité personnalisée, le menu se retrouvait avec deux
    // entrées de même valeur — ce que le menu déroulant refuse, et il lève
    // une assertion au rendu suivant.
    final controller = TextEditingController();

    await tester.pumpWidget(hote(controller: controller));

    await tester.tap(find.text('Ajouter une unité'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'sac');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.text, 'sac');
  });

  testWidgets("la même unité à la casse près ne duplique pas le menu",
      (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(hote(controller: controller));

    await tester.tap(find.text('Ajouter une unité'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'KG');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets("l'ajout reste atteignable quand une unité est déjà choisie",
      (tester) async {
    // Le menu s'ouvre centré sur l'unité sélectionnée et ne construit que ce
    // qui est visible : une commande placée dans la liste était inatteignable
    // dès qu'un article avait déjà une unité.
    await tester.pumpWidget(
      hote(controller: TextEditingController(text: 'kg')),
    );

    expect(find.text('Ajouter une unité'), findsOneWidget);
  });

  testWidgets('annuler l\'ajout laisse l\'unité d\'origine intacte',
      (tester) async {
    final controller = TextEditingController(text: 'kg');

    await tester.pumpWidget(hote(controller: controller));

    await tester.tap(find.text('Ajouter une unité'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(controller.text, 'kg');
    expect(tester.takeException(), isNull);
  });

  testWidgets('une unité déjà connue de l\'équipe n\'apparaît pas deux fois',
      (tester) async {
    // Le parent recharge la liste après création : la nouvelle unité arrive
    // alors par deux chemins à la fois.
    final controller = TextEditingController();

    await tester.pumpWidget(
      hote(
        controller: controller,
        custom: const ['botte'],
        onCreate: (_) async {},
      ),
    );

    await tester.tap(find.text('Ajouter une unité'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'botte');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    // Deux entrées de même valeur feraient échouer l'assertion du menu
    // déroulant au prochain rendu.
    expect(tester.takeException(), isNull);
    expect(controller.text, 'botte');
  });
}
