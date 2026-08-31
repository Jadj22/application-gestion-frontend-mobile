import 'package:dodome/core/offline/connectivity/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'état de connexion au tout premier instant du démarrage.
///
/// Ces invariants ont l'air anodins mais chacun corrige un défaut constaté au
/// lancement sur un appareil réel : l'application restait figée pendant que la
/// sonde réseau expirait, et affichait « Hors ligne » avant d'avoir rien vérifié.
void main() {
  group('État initial', () {
    test('l\'état n\'est pas « hors ligne » avant d\'avoir été mesuré', () {
      final service = ConnectivityService();
      addTearDown(service.dispose);

      expect(service.status, ConnectionStatus.unknown);
      // Affirmer « Hors ligne » sans avoir vérifié serait faux, et le bandeau
      // clignoterait à chaque démarrage.
      expect(service.isOffline, isFalse);
      expect(service.isOnline, isFalse);
      expect(service.isDetermined, isFalse);
    });

    test('un appel réseau est tenté tant que l\'état est inconnu', () {
      final service = ConnectivityService();
      addTearDown(service.dispose);

      // Sinon, au tout premier lancement (base locale vide), les écrans
      // s'ouvriraient vides et ne se rempliraient jamais.
      expect(service.worthTrying, isTrue);
    });
  });

  group('Après mesure', () {
    test('un succès réel fait passer en ligne', () {
      final service = ConnectivityService();
      addTearDown(service.dispose);

      service.reportSuccess();

      expect(service.isOnline, isTrue);
      expect(service.isDetermined, isTrue);
      expect(service.isOffline, isFalse);
    });

    test('un échec réseau après un succès repasse hors ligne', () {
      final service = ConnectivityService();
      addTearDown(service.dispose);

      service.reportSuccess();
      service.reportNetworkFailure();

      expect(service.status, ConnectionStatus.serverUnreachable);
      expect(service.isOffline, isTrue);
      expect(service.worthTrying, isFalse);
    });

    test('la première mesure « en ligne » n\'est pas un retour de réseau', () async {
      final service = ConnectivityService();
      addTearDown(service.dispose);

      // `onBackOnline` déclenche la synchronisation de rattrapage. L'émettre au
      // démarrage ferait partir un cycle en double avec celui de l'ouverture.
      var backOnlineEvents = 0;
      service.onBackOnline.listen((_) => backOnlineEvents++);

      service.reportSuccess();
      await Future<void>.delayed(Duration.zero);
      expect(backOnlineEvents, 0);

      // En revanche, un vrai retour après une coupure doit bien le signaler.
      service.reportNetworkFailure();
      service.reportSuccess();
      await Future<void>.delayed(Duration.zero);
      expect(backOnlineEvents, 1);
    });
  });
}
