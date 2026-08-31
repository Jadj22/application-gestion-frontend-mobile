import 'package:flutter_test/flutter_test.dart';

import 'package:dodome/features/auth/data/auth_repository.dart';
import 'package:dodome/features/auth/data/models/user.dart';
import 'package:dodome/features/business/data/models/business.dart';
import 'package:dodome/features/business/data/models/business_type.dart';
import 'package:dodome/features/home/data/home_repository.dart';
import 'package:dodome/features/items/data/models/category.dart';
import 'package:dodome/features/items/data/models/catalog_item.dart';
import 'package:dodome/features/items/data/models/image_description.dart';
import 'package:dodome/features/items/data/models/item.dart';
import 'package:dodome/features/items/data/models/item_detail.dart';
import 'package:dodome/features/items/data/models/stock_movement.dart';
import 'package:dodome/features/maintenance/data/models/maintenance_task.dart';
import 'package:dodome/features/maintenance/data/models/procedure.dart';
import 'package:dodome/features/members/data/models/member.dart';
import 'package:dodome/features/members/data/models/role.dart';

void main() {
  group('User', () {
    test('parse la réponse UserSerializer', () {
      final user = User.fromJson({
        'id': 'u1',
        'email': 'joel@exemple.com',
        'first_name': 'Joel',
        'last_name': 'Agbo',
        'telephone': '+229',
        'statut': 'ACTIF',
      });
      expect(user.displayName, 'Joel Agbo');
      expect(user.initials, 'JA');
    });

    test('fallback email quand pas de prénom/nom', () {
      final user = User.fromJson({'id': 'u1', 'email': 'kossi@exemple.com'});
      expect(user.displayName, 'kossi@exemple.com');
      expect(user.initials, 'K');
    });
  });

  group('Business', () {
    test('parse la réponse de /businesses/ (avec role)', () {
      final business = Business.fromJson({
        'id': 'b1',
        'nom': 'Decoration Joel',
        'role': 'OWNER',
        'created_at': '2026-08-17T10:00:00Z',
      });
      expect(business.id, 'b1');
      expect(business.role, 'OWNER');
      expect(business.createdAt, isNotNull);
    });

    test('parse la réponse de /auth/me/ (avec role_id)', () {
      final business = Business.fromJson({
        'id': 'b1',
        'nom': 'Decoration Joel',
        'role': 'ADMIN',
        'role_id': 'r-admin',
        'statut': 'ACTIF',
      });
      expect(business.roleId, 'r-admin');
      expect(business.statut, 'ACTIF');
    });
  });

  group('BusinessType', () {
    test('parse le catalogue', () {
      final type = BusinessType.fromJson(
          {'codename': 'DECORATION_RENTAL', 'libelle': 'Location & Décoration'});
      expect(type.codename, 'DECORATION_RENTAL');
      expect(type.libelle, 'Location & Décoration');
    });
  });

  group('Role', () {
    test('parse les permissions embarquées', () {
      final role = Role.fromJson({
        'id': 'r1',
        'nom': 'ADMIN',
        'description': '',
        'is_system': true,
        'permissions': [
          {'codename': 'member.invite', 'libelle': 'Inviter un membre'},
          {'codename': 'member.role_update', 'libelle': 'Attribuer un rôle'},
        ],
      });
      expect(role.isSystem, isTrue);
      expect(role.hasPermission('member.invite'), isTrue);
      expect(role.hasPermission('business.update'), isFalse);
    });
  });

  group('Member', () {
    test('parse la réponse BusinessMemberSerializer', () {
      final member = Member.fromJson({
        'id': 'm1',
        'user': {
          'id': 'u1',
          'email': 'kossi@exemple.com',
          'first_name': 'Kossi',
          'last_name': 'Agbo',
          'telephone': '',
          'statut': 'ACTIF',
        },
        'role': {
          'id': 'r1',
          'nom': 'ADMIN',
          'description': '',
          'is_system': true,
          'permissions': [],
        },
        'statut': 'ACTIF',
        'invited_by': null,
        'invited_at': '2026-08-17T10:00:00Z',
      });
      expect(member.role?.nom, 'ADMIN');
      expect(member.isActive, isTrue);
      expect(member.isOwner, isFalse);
    });

    test('détecte le propriétaire (RM-17)', () {
      final member = Member.fromJson({
        'id': 'm1',
        'user': {'id': 'u1', 'email': 'joel@exemple.com'},
        'role': {
          'id': 'r1',
          'nom': 'OWNER',
          'description': '',
          'is_system': true,
          'permissions': [],
        },
        'statut': 'ACTIF',
      });
      expect(member.isOwner, isTrue);
    });
  });

  group('HomeAlert (HomeRepository)', () {
    test('parse une alerte AVERTISSEMENT (maintenance)', () {
      final alert = HomeAlert.fromJson({
        'id': 'a1',
        'item_nom': 'Couteau',
        'code': 'ARTICLE_EN_ENTRETIEN',
        'mode': 'AVERTISSEMENT',
        'message': 'Article en entretien',
        'created_at': '2026-08-17T10:00:00Z',
      });
      expect(alert.severity, AlertSeverity.maintenance);
      expect(alert.title, 'Article en entretien');
      expect(alert.createdAt, isNotNull);
    });

    test('parse une alerte BLOCAGE (critique)', () {
      final alert = HomeAlert.fromJson({
        'id': 'a2',
        'item_nom': 'Tente',
        'code': 'ARTICLE_A_VERIFIER',
        'mode': 'BLOCAGE',
        'message': 'Article à vérifier',
      });
      expect(alert.severity, AlertSeverity.critical);
    });
  });

  group('RecentItemModel (HomeRepository)', () {
    test('parse une ligne de /stock/ (disponibles > 0)', () {
      final item = RecentItemModel.fromJson({
        'item_id': 'i1',
        'nom': 'Couteau de cuisine',
        'reference': 'SKU-8921-KN',
        'statut': 'ACTIF',
        'total': 10,
        'disponibles': 6,
      });
      expect(item.name, 'Couteau de cuisine');
      expect(item.sku, 'SKU-8921-KN');
      expect(item.status, ItemStatus.available);
    });

    test('stock épuisé -> low', () {
      final item = RecentItemModel.fromJson({
        'item_id': 'i2',
        'nom': 'Bol',
        'reference': 'SKU-4310-BO',
        'statut': 'ACTIF',
        'total': 2,
        'disponibles': 0,
      });
      expect(item.status, ItemStatus.low);
    });

    test('article INACTIF ou jamais stocké -> unavailable', () {
      final inactif = RecentItemModel.fromJson({
        'item_id': 'i3',
        'nom': 'Machine',
        'reference': 'SKU-1122-MC',
        'statut': 'INACTIF',
        'total': 5,
        'disponibles': 5,
      });
      expect(inactif.status, ItemStatus.unavailable);

      final jamais = RecentItemModel.fromJson({
        'item_id': 'i4',
        'nom': 'Nappe',
        'reference': 'SKU-0001-NA',
        'statut': 'ACTIF',
        'total': 0,
        'disponibles': 0,
      });
      expect(jamais.status, ItemStatus.unavailable);
    });
  });

  group('CategoryModel', () {
    test('parse CategorySerializer', () {
      final category = CategoryModel.fromJson({
        'id': 'c1',
        'nom': 'Coutellerie',
        'description': 'Couteaux et ustensiles',
      });
      expect(category.id, 'c1');
      expect(category.nom, 'Coutellerie');
    });
  });

  group('ItemModel', () {
    test('parse ItemSerializer', () {
      final item = ItemModel.fromJson({
        'id': 'i1',
        'nom': 'Couteau de cuisine',
        'reference': 'SKU-0001-KN',
        'description': 'Lame inox',
        'prix': '5000',
        'unite': 'pièce',
        'statut': 'ACTIF',
        'entretien_requis': true,
        'category': {'id': 'c1', 'nom': 'Coutellerie'},
      });
      expect(item.id, 'i1');
      expect(item.nom, 'Couteau de cuisine');
      expect(item.reference, 'SKU-0001-KN');
      expect(item.prix, 5000);
      expect(item.entretienRequis, isTrue);
      expect(item.categoryNom, 'Coutellerie');
    });

    test('valeurs par défaut quand les champs manquent', () {
      final item = ItemModel.fromJson({'id': 'i2', 'nom': 'Bol'});
      expect(item.statut, 'ACTIF');
      expect(item.entretienRequis, isNull);
      expect(item.categoryNom, isNull);
    });
  });

  group('StockMovementModel', () {
    test('parse StockMovementSerializer', () {
      final movement = StockMovementModel.fromJson({
        'id': 'm1',
        'type': 'ENTREE',
        'quantite': 12,
        'motif': 'Livraison fournisseur',
        'reference': 'BL-2026-001',
        'item_nom': 'Couteau de cuisine',
        'date': '2026-08-17T10:00:00Z',
      });
      expect(movement.type, 'ENTREE');
      expect(movement.quantite, 12);
      expect(movement.itemNom, 'Couteau de cuisine');
      expect(movement.reference, 'BL-2026-001');
    });
  });

  group('ItemDetailModel', () {
    test('parse ItemSerializer + /stock/ (fiche article)', () {
      final detail = ItemDetailModel.fromJson(
        {
          'id': 'i1',
          'nom': 'Couteau de cuisine',
          'reference': '89234',
          'description': 'Acier inoxydable',
          'prix': '5000',
          'unite': 'pièce',
          'entretien_requis': true,
          'category': {'id': 'c1', 'nom': 'Coutellerie'},
          'photos': [{'id': 'p1', 'image': '/media/photos/pixel.png'}],
        },
        stock: {
          'total': 12,
          'disponibles': 8,
          'sorties': 3,
          'endommages': 1,
          'perdus': 0,
          'a_verifier': true,
          'etat_entretien': {'code': 'PRET', 'libelle': 'Prêt à l\'usage'},
        },
      );
      expect(detail.id, 'i1');
      expect(detail.nom, 'Couteau de cuisine');
      expect(detail.ref, '89234');
      expect(detail.total, 12);
      expect(detail.disponibles, 8);
      expect(detail.categorie, 'Coutellerie');
      expect(detail.categoryId, 'c1');
      expect(detail.aVerifier, isTrue);
      expect(detail.alerteLabel, 'À VÉRIFIER');
      expect(detail.conditionLabel, 'PRÊT À L\'USAGE');
      expect(detail.photoUrl, endsWith('/media/photos/pixel.png'));
    });

    test('valeurs par défaut quand les champs manquent', () {
      final detail = ItemDetailModel.fromJson({'id': 'i2', 'nom': 'Bol'});
      expect(detail.total, 0);
      expect(detail.categorie, isNull);
      expect(detail.ref, '');
      expect(detail.alerteLabel, 'AUCUNE');
      expect(detail.conditionLabel, 'PRÊT');
    });
  });

  group('CatalogItemModel', () {
    test('parse ItemSerializer + stock disponible', () {
      final item = CatalogItemModel.fromJson(
        {
          'id': 'i1',
          'nom': 'Couteau de cuisine',
          'reference': '89234',
          'category': {'id': 'c1', 'nom': 'Coutellerie'},
          'photos': [{'id': 'p1', 'image': '/media/photos/pixel.png'}],
        },
        stock: {'total': 10, 'disponibles': 8, 'sorties': 2},
      );
      expect(item.id, 'i1');
      expect(item.nom, 'Couteau de cuisine');
      expect(item.sku, '89234');
      expect(item.categorie, 'Coutellerie');
      expect(item.categoryId, 'c1');
      expect(item.quantite, 8);
      expect(item.total, 10);
      expect(item.sorties, 2);
      expect(item.photoUrl, endsWith('/media/photos/pixel.png'));
      expect(item.inactif, isFalse);
      expect(item.faible, isFalse);
    });

    test('statut faible / inactif quand la quantité le justifie', () {
      final faible = CatalogItemModel.fromJson(
        {'id': 'i1', 'nom': 'Couteau'},
        stock: {'disponibles': 0},
      );
      expect(faible.quantite, 0);
      expect(faible.faible, isTrue);
      expect(faible.inactif, isFalse);

      final inactif = CatalogItemModel.fromJson(
        {'id': 'i2', 'nom': 'Bol', 'statut': 'INACTIF'},
        stock: {'disponibles': 0},
      );
      expect(inactif.inactif, isTrue);

      final zero = CatalogItemModel.fromJson(
        {'id': 'i3', 'nom': 'Assiette', 'statut': 'ACTIF'},
        stock: {'disponibles': 0},
      );
      expect(zero.faible, isTrue);
    });

    test('parse l\'état complet du stock (entretien, à vérifier)', () {
      final item = CatalogItemModel.fromJson(
        {'id': 'i4', 'nom': 'Chaise', 'statut': 'ACTIF'},
        stock: {
          'total': 100,
          'disponibles': 70,
          'sorties': 30,
          'endommages': 2,
          'perdus': 1,
          'entretien_requis': true,
          'etat_entretien': {'libelle': 'réparation'},
          'a_verifier': true,
        },
      );
      expect(item.total, 100);
      expect(item.quantite, 70);
      expect(item.endommages, 2);
      expect(item.perdus, 1);
      expect(item.entretienRequis, isTrue);
      expect(item.etatEntretien, 'RÉPARATION');
      expect(item.aVerifier, isTrue);
    });
  });

  group('MaintenanceTaskModel', () {
    test('parse MaintenanceTaskSerializer', () {
      final task = MaintenanceTaskModel.fromJson({
        'id': 't1',
        'item_id': 'i1',
        'item_nom': 'Couteau de cuisine',
        'procedure_nom': 'Affûtage mensuel',
        'motif': 'Lame émoussée',
        'statut': 'EN_COURS',
        'etapes': {'total': 4, 'faites': 1},
        'etat_article': {'code': 'PRET', 'libelle': 'Prêt à l\'usage'},
        'created_at': '2026-08-18T09:00:00Z',
      });
      expect(task.id, 't1');
      expect(task.itemNom, 'Couteau de cuisine');
      expect(task.procedureNom, 'Affûtage mensuel');
      expect(task.estEnCours, isTrue);
      expect(task.estTerminee, isFalse);
      expect(task.etapesTotal, 4);
      expect(task.etapesFaites, 1);
      expect(task.progressValue, 25);
      expect(task.etatArticle, 'PRÊT À L\'USAGE');
      expect(task.statutLabel, 'EN COURS');
    });

    test('statut terminé et valeurs par défaut', () {
      final terminee = MaintenanceTaskModel.fromJson({
        'id': 't2',
        'statut': 'TERMINEE',
        'etapes': {'total': 3, 'faites': 3},
      });
      expect(terminee.estTerminee, isTrue);
      expect(terminee.progressValue, 100);
      expect(terminee.itemId, '');
      expect(terminee.itemNom, '');
      expect(terminee.etatArticle, '—');

      final partielle = MaintenanceTaskModel.fromJson({
        'id': 't3',
        'statut': 'PARTIELLE',
        'etapes': {'total': 2, 'faites': 1},
      });
      expect(partielle.estEnCours, isTrue);
      expect(partielle.statutLabel, 'PARTIELLE');
    });
  });

  group('ProcedureModel', () {
    test('parse ProcedureSerializer', () {
      final procedure = ProcedureModel.fromJson({
        'id': 'p1',
        'nom': 'Affûtage mensuel',
        'description': 'Vérification des lames',
        'est_actif': true,
      });
      expect(procedure.id, 'p1');
      expect(procedure.nom, 'Affûtage mensuel');
      expect(procedure.estActif, isTrue);
    });
  });

  group('InvitationPreview', () {
    test('parse GET /invitations/<token>/ (Sprint 10)', () {
      final preview = InvitationPreview.fromJson({
        'email': 'kossi@exemple.com',
        'business_id': 'b1',
        'business_nom': 'Decoration Joel',
        'inviteur': 'alice@demo.com',
        'role': 'MEMBER',
        'statut': 'INVITE',
      });
      expect(preview.email, 'kossi@exemple.com');
      expect(preview.businessId, 'b1');
      expect(preview.businessNom, 'Decoration Joel');
      expect(preview.inviteur, 'alice@demo.com');
      expect(preview.role, 'MEMBER');
      expect(preview.statut, 'INVITE');
    });

    test('champs optionnels nuls', () {
      final preview = InvitationPreview.fromJson({
        'email': 'kossi@exemple.com',
        'business_id': 'b1',
        'business_nom': 'Decoration Joel',
        'inviteur': null,
        'role': null,
        'statut': 'INVITE',
      });
      expect(preview.inviteur, isNull);
      expect(preview.role, isNull);
    });
  });

  group('ImageDescription', () {
    test('parse la réponse Gemini (Sprint 10)', () {
      final result = ImageDescription.fromJson({
        'nom': 'Tente 3x3',
        'description': 'Tente de camping trois places, verte, avec housse.',
      });
      expect(result.nom, 'Tente 3x3');
      expect(result.description, contains('Tente de camping'));
      expect(result.hasContent, isTrue);
    });

    test('réponse vide (article non identifié)', () {
      final result = ImageDescription.fromJson({'nom': '', 'description': ''});
      expect(result.hasContent, isFalse);
    });

    test('parse la fiche enrichie (catégorie, référence, caractéristiques)', () {
      final result = ImageDescription.fromJson({
        'nom': 'Tasse bleue',
        'description': 'Tasse en céramique bleue avec anse.',
        'categorie': 'Vaisselle',
        'category_id': 'cat-1',
        'reference': 'TAS-BLE-001',
        'unite': 'pièce',
        'etat': 'NEUF',
        'caracteristiques': {'Couleur': 'Bleu', 'Matière': 'Céramique'},
        'confiance': 'HAUTE',
      });
      expect(result.categoryId, 'cat-1');
      expect(result.categorie, 'Vaisselle');
      expect(result.reference, 'TAS-BLE-001');
      expect(result.unite, 'pièce');
      expect(result.etatLisible, 'Neuf');
      expect(result.caracteristiques, hasLength(2));
      expect(result.caracteristiques['Matière'], 'Céramique');
      expect(result.confianceFaible, isFalse);
      expect(result.proposeUneNouvelleCategorie, isFalse);
    });

    test('catégorie absente du catalogue : proposition à créer', () {
      final result = ImageDescription.fromJson({
        'nom': 'Perceuse',
        'description': 'Perceuse sans fil.',
        'categorie': 'Outillage',
        'category_id': null,
      });
      expect(result.categoryId, isNull);
      expect(result.proposeUneNouvelleCategorie, isTrue);
    });

    test('category_id vide traité comme absent', () {
      final result = ImageDescription.fromJson({
        'nom': 'Objet',
        'description': 'Description.',
        'categorie': 'Divers',
        'category_id': '',
      });
      expect(result.categoryId, isNull);
    });

    test('caractéristiques vides ou mal formées ignorées', () {
      final result = ImageDescription.fromJson({
        'nom': 'Objet',
        'description': 'Description.',
        'caracteristiques': {'Couleur': '  ', '  ': 'Bleu', 'Matière': 'Bois'},
      });
      expect(result.caracteristiques, {'Matière': 'Bois'});
    });

    test('confiance faible signalée à l\'utilisateur', () {
      final result = ImageDescription.fromJson({
        'nom': 'Objet flou',
        'description': 'Photo peu nette.',
        'confiance': 'FAIBLE',
      });
      expect(result.confianceFaible, isTrue);
      expect(result.confianceLisible, 'Identification incertaine');
    });

    test('champs absents : valeurs par défaut sûres', () {
      final result = ImageDescription.fromJson({
        'nom': 'Tente 3x3',
        'description': 'Tente de camping.',
      });
      expect(result.categorie, '');
      expect(result.categoryId, isNull);
      expect(result.reference, '');
      expect(result.etat, 'INCONNU');
      expect(result.etatLisible, 'État indéterminé');
      expect(result.caracteristiques, isEmpty);
      expect(result.confiance, 'MOYENNE');
    });

  });
}
