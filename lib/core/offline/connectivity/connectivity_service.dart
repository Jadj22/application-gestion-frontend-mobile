import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import '../../network/api_endpoints.dart';

/// État de connexion effectif de l'application.
enum ConnectionStatus {
  /// L'état n'a pas encore été mesuré (tout premier instant du démarrage).
  ///
  /// Distinct de `offline` : afficher « Hors ligne » avant d'avoir vérifié
  /// serait un mensonge, et refuser les lectures réseau bloquerait le premier
  /// lancement sur une base locale vide.
  unknown,

  /// Le backend répond : les opérations peuvent partir.
  online,

  /// Aucune interface réseau utilisable.
  offline,

  /// Une interface réseau existe mais le backend ne répond pas : portail
  /// captif, VPN, DNS cassé, serveur éteint, coupure côté hébergeur.
  /// Fonctionnellement identique à `offline` pour la synchronisation, mais
  /// distinct pour pouvoir l'expliquer à l'utilisateur.
  serverUnreachable,
}

/// Détecte si l'application peut réellement parler au backend.
///
/// Le point important : **être associé à un Wi-Fi ne veut pas dire avoir
/// Internet**, et avoir Internet ne veut pas dire que l'API répond. Le
/// changement d'interface réseau signalé par le système n'est donc utilisé que
/// comme *déclencheur* — c'est une requête réelle sur [ApiEndpoints.health] qui
/// tranche.
class ConnectivityService extends ChangeNotifier {
  /// Intervalle de re-vérification quand on se croit en ligne.
  static const Duration onlinePollInterval = Duration(minutes: 2);

  /// Intervalle de re-vérification quand on se croit hors ligne : plus court,
  /// pour repartir vite dès que le réseau revient.
  static const Duration offlinePollInterval = Duration(seconds: 20);

  /// Une sonde qui traîne est une sonde qui échoue : sur un réseau mort, mieux
  /// vaut conclure vite que bloquer l'interface.
  static const Duration probeTimeout = Duration(seconds: 5);

  final Connectivity _connectivity;
  final http.Client _client;

  ConnectionStatus _status = ConnectionStatus.unknown;
  DateTime? _lastProbeAt;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Future<bool>? _inFlightProbe;
  bool _disposed = false;

  ConnectivityService({Connectivity? connectivity, http.Client? client})
      : _connectivity = connectivity ?? Connectivity(),
        _client = client ?? http.Client();

  ConnectionStatus get status => _status;
  bool get isOnline => _status == ConnectionStatus.online;

  /// Hors ligne **avéré** : l'état a été mesuré et le backend ne répond pas.
  /// Tant que rien n'a été mesuré, on n'affirme pas être hors ligne.
  bool get isOffline => _status == ConnectionStatus.offline ||
      _status == ConnectionStatus.serverUnreachable;

  /// L'état a-t-il déjà été mesuré au moins une fois ?
  bool get isDetermined => _status != ConnectionStatus.unknown;

  /// Faut-il tenter un appel réseau ? Vrai si l'on se sait en ligne, ou si
  /// l'on ne sait pas encore — auquel cas l'appel lui-même fera office de
  /// sonde et retombera sur la base locale s'il échoue.
  bool get worthTrying => isOnline || !isDetermined;
  DateTime? get lastProbeAt => _lastProbeAt;

  /// Émis à chaque bascule hors ligne → en ligne. C'est le signal qui déclenche
  /// la synchronisation automatique.
  final StreamController<void> _backOnline = StreamController<void>.broadcast();
  Stream<void> get onBackOnline => _backOnline.stream;

  /// Démarre la surveillance.
  ///
  /// La première sonde est lancée **sans être attendue** : elle peut prendre
  /// plusieurs secondes sur un réseau mort, et bloquer l'affichage du premier
  /// écran pendant ce temps irait à l'encontre du principe même de
  /// l'architecture — l'application doit s'ouvrir instantanément, réseau ou
  /// pas. L'état bascule tout seul dès que la réponse arrive.
  Future<void> start() async {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasInterface =
          results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _apply(ConnectionStatus.offline);
        return;
      }
      // Interface disponible : ça ne prouve rien, on va vérifier.
      unawaited(probe());
    });

    unawaited(probe());
    _scheduleNext();
  }

  /// Force une vérification immédiate de l'accessibilité du backend.
  ///
  /// Les appels concurrents partagent la même requête : dix écrans qui
  /// demandent l'état au même moment ne doivent pas produire dix requêtes.
  Future<bool> probe() {
    final inFlight = _inFlightProbe;
    if (inFlight != null) return inFlight;

    final future = _runProbe();
    _inFlightProbe = future;
    return future.whenComplete(() => _inFlightProbe = null);
  }

  Future<bool> _runProbe() async {
    final results = await _connectivity.checkConnectivity();
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      _apply(ConnectionStatus.offline);
      return false;
    }

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}${ApiEndpoints.health}');
      final response = await _client.get(uri).timeout(probeTimeout);
      _lastProbeAt = DateTime.now();
      // Toute réponse HTTP prouve que le backend est joignable. Un 5xx signale
      // un serveur en difficulté : inutile de vider la file dessus.
      final reachable = response.statusCode < 500;
      _apply(
        reachable ? ConnectionStatus.online : ConnectionStatus.serverUnreachable,
      );
      return reachable;
    } catch (_) {
      _lastProbeAt = DateTime.now();
      _apply(ConnectionStatus.serverUnreachable);
      return false;
    }
  }

  /// Renseigne l'état depuis le résultat d'un appel API réel.
  ///
  /// Une requête métier qui vient d'aboutir est une preuve d'accessibilité plus
  /// fraîche que n'importe quelle sonde : autant s'en servir.
  void reportSuccess() => _apply(ConnectionStatus.online);

  /// Signale qu'un appel a échoué faute de réseau. On repasse hors ligne sans
  /// attendre le prochain cycle de sonde.
  void reportNetworkFailure() {
    if (_status == ConnectionStatus.online) {
      _apply(ConnectionStatus.serverUnreachable);
    }
  }

  void _apply(ConnectionStatus next) {
    if (_disposed || _status == next) return;
    // Une premiere mesure qui conclut « en ligne » ne doit pas etre traitee
    // comme un retour de reseau : il n'y a rien a rattraper au demarrage, la
    // synchronisation d'ouverture s'en charge deja.
    final wasOffline = _status == ConnectionStatus.offline ||
        _status == ConnectionStatus.serverUnreachable;
    _status = next;
    notifyListeners();
    _scheduleNext();
    if (wasOffline && next == ConnectionStatus.online) {
      _backOnline.add(null);
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_disposed) return;
    _timer = Timer(
      isOnline ? onlinePollInterval : offlinePollInterval,
      () => unawaited(probe()),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_backOnline.close());
    _client.close();
    super.dispose();
  }
}
