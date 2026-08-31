import 'package:google_sign_in/google_sign_in.dart';

/// Récupère l'ID token Google (OAuth 2.0 mobile) pour /auth/google/.
class GoogleSignInService {
  // Client OAuth Android du google-services.json : l'aud de l'ID token doit
  // figurer dans GOOGLE_CLIENT_IDS côté backend (config/settings.py).
  static const String _serverClientId =
      '976579848816-0snvj73v3bhvh28prtmaqhn8rqlfleik.apps.googleusercontent.com';

  final GoogleSignIn _signIn = GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _signIn.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }

  /// Ouvre le sélecteur de compte Google et retourne l'ID token.
  /// Retourne null si l'utilisateur annule.
  Future<String?> signIn() async {
    await _ensureInitialized();
    final GoogleSignInAccount account;
    try {
      account = await _signIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      await _signIn.disconnect();
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Google n\'a pas retourné de jeton d\'identification.',
      );
    }
    return idToken;
  }
}