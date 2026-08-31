import 'package:dodome/features/items/data/item_assist_service.dart';
import 'package:dodome/features/items/data/item_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Préfixe de référence', () {
    test('reprend les trois premiers mots significatifs', () {
      // Doit correspondre à ce que produit le serveur, pour que la forme des
      // références reste la même qu'elles soient calculées ici ou là-bas.
      expect(
        ItemAssistService.referencePrefix('Chaise pliante en bois'),
        'CHA-PLI-BOI',
      );
      expect(
        ItemAssistService.referencePrefix('Nappe pour table'),
        'NAP-TAB',
      );
    });

    test('ignore les accents et la ponctuation', () {
      expect(ItemAssistService.referencePrefix('Théière'), 'THE');
      expect(ItemAssistService.referencePrefix('Café/Thé'), 'CAF');
    });

    test('un nom vide ne produit pas de référence', () {
      expect(ItemAssistService.referencePrefix(''), '');
      expect(ItemAssistService.referencePrefix('   '), '');
    });

    test('un nom fait uniquement de mots vides reste exploitable', () {
      // Plutôt que de renvoyer une chaîne vide et de bloquer l'utilisateur,
      // on retombe sur les mots eux-mêmes.
      expect(ItemAssistService.referencePrefix('de la'), 'DE-LA');
    });

    test('les mots courts ne sont pas tronqués au-delà de leur longueur', () {
      expect(ItemAssistService.referencePrefix('Ré'), 'RE');
    });
  });

  group('Unités', () {
    test('les valeurs historiques sont rattachées à la liste', () {
      // Les articles saisis avant la liste contiennent des variantes libres :
      // les rattacher évite de les afficher comme des unités personnalisées.
      expect(ItemUnits.normalize('Kg'), 'kg');
      expect(ItemUnits.normalize('kilogramme'), 'kg');
      expect(ItemUnits.normalize('piece'), 'pièce');
      expect(ItemUnits.normalize('  litres '), 'L');
      expect(ItemUnits.normalize('boite'), 'boîte');
    });

    test('une unité inconnue reste inconnue plutôt que devinée', () {
      // Deviner ferait pire que mieux : mieux vaut la traiter comme
      // personnalisée et la conserver telle quelle.
      expect(ItemUnits.normalize('brouettes'), isNull);
      expect(ItemUnits.normalize(''), isNull);
      expect(ItemUnits.normalize(null), isNull);
    });

    test('toutes les valeurs tiennent dans la colonne du backend', () {
      // `Item.unite` est un CharField(max_length=30) : une valeur plus longue
      // serait rejetée à la création.
      for (final unit in ItemUnits.all) {
        expect(
          unit.value.length,
          lessThanOrEqualTo(ItemUnits.maxLength),
          reason: '${unit.value} dépasse la limite du backend',
        );
      }
    });

    test('les valeurs sont uniques', () {
      final values = ItemUnits.all.map((u) => u.value).toList();
      expect(values.toSet().length, values.length);
    });

    test('l\'unité par défaut fait partie de la liste', () {
      expect(ItemUnits.isKnown(ItemUnits.defaultValue), isTrue);
    });
  });

  group('Sources IA', () {
    test('chaque source a une valeur distincte pour le backend', () {
      final wire = AiSource.values.map((s) => s.wireValue).toList();
      expect(wire.toSet().length, wire.length);
    });

    test('les valeurs correspondent au contrat du serveur', () {
      // Le backend n'accepte que ces libellés (ItemDescriptionSerializer).
      expect(AiSource.nom.wireValue, 'nom');
      expect(AiSource.motsCles.wireValue, 'mots_cles');
      expect(AiSource.champs.wireValue, 'champs');
      expect(AiSource.amelioration.wireValue, 'amelioration');
      expect(AiSource.libre.wireValue, 'libre');
    });

    test('chaque source est présentable à l\'utilisateur', () {
      for (final source in AiSource.values) {
        expect(source.label, isNotEmpty);
        expect(source.hint, isNotEmpty);
      }
    });
  });
}
