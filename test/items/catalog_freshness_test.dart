import 'package:dodome/features/items/data/models/catalog_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Régression : un article dont l'état du stock n'est pas encore connu était
/// affiché « Épuisé ».
///
/// La cause était une confusion entre deux situations que rien ne distinguait :
/// « le stock vaut zéro » et « on ne sait pas encore ce que vaut le stock ».
/// Les compteurs manquants retombaient sur 0, et le badge concluait à la
/// rupture — sur un article qu'on venait de créer avec dix unités.
void main() {
  Map<String, dynamic> item({String id = 'srv-1', String statut = 'ACTIF'}) => {
        'id': id,
        'nom': 'Chaise',
        'statut': statut,
      };

  group('Stock inconnu', () {
    test('un article sans ligne de stock n\'est pas déclaré épuisé', () {
      final ligne = CatalogItemModel.fromJson(item());

      expect(ligne.stockConnu, isFalse);
      expect(ligne.epuise, isFalse);
      expect(ligne.faible, isFalse);
    });

    test('une ligne de stock vide vaut « inconnu », pas « zéro »', () {
      // Le serveur peut renvoyer un objet vide ; c'est une absence
      // d'information, pas une rupture constatée.
      final ligne = CatalogItemModel.fromJson(item(), stock: const {});

      expect(ligne.stockConnu, isFalse);
      expect(ligne.epuise, isFalse);
    });
  });

  group('Stock connu', () {
    test('un stock réellement à zéro est bien signalé', () {
      final ligne = CatalogItemModel.fromJson(
        item(),
        stock: const {'total': 0, 'disponibles': 0},
      );

      expect(ligne.stockConnu, isTrue);
      expect(ligne.epuise, isTrue);
    });

    test('un stock disponible n\'est jamais épuisé', () {
      final ligne = CatalogItemModel.fromJson(
        item(),
        stock: const {'total': 10, 'disponibles': 10},
      );

      expect(ligne.quantite, 10);
      expect(ligne.epuise, isFalse);
    });

    test('un article inactif n\'est pas compté comme épuisé', () {
      // Inactif et épuisé sont deux états distincts : les confondre ferait
      // remonter les articles archivés dans les alertes de rupture.
      final ligne = CatalogItemModel.fromJson(
        item(statut: 'INACTIF'),
        stock: const {'total': 0, 'disponibles': 0},
      );

      expect(ligne.inactif, isTrue);
      expect(ligne.epuise, isFalse);
    });

    test('tout sorti mais rien de disponible reste une rupture', () {
      final ligne = CatalogItemModel.fromJson(
        item(),
        stock: const {'total': 5, 'disponibles': 0, 'sorties': 5},
      );

      expect(ligne.epuise, isTrue);
      expect(ligne.sorties, 5);
    });
  });
}
