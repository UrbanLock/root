import 'package:shared_preferences/shared_preferences.dart';

/// Servizio per gestire l'autenticazione e i token JWT
/// Singleton che gestisce access token e refresh token
class AuthService {
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyTokenExpiry = 'token_expiry';

  static AuthService? _instance;
  SharedPreferences? _prefs;

  AuthService._();

  /// Ottiene l'istanza singleton
  static Future<AuthService> getInstance() async {
    _instance ??= AuthService._();
    _instance!._prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// Salva i token dopo il login
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    int expiresInSeconds = 900, // 15 minuti di default
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    
    // Calcola scadenza (timestamp attuale + expiresIn)
    final expiry = DateTime.now().add(Duration(seconds: expiresInSeconds));
    await prefs.setInt(_keyTokenExpiry, expiry.millisecondsSinceEpoch);
  }

  /// Ottiene l'access token corrente
  String? getAccessToken() {
    return _prefs?.getString(_keyAccessToken);
  }

  /// Ottiene il refresh token corrente
  String? getRefreshToken() {
    return _prefs?.getString(_keyRefreshToken);
  }

  /// Verifica se il token è scaduto
  bool isTokenExpired() {
    final expiryTimestamp = _prefs?.getInt(_keyTokenExpiry);
    if (expiryTimestamp == null) return true;
    
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
    // Considera scaduto se mancano meno di 1 minuto
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 1)));
  }

  /// Verifica se l'utente è autenticato
  bool isAuthenticated() {
    final token = getAccessToken();
    return token != null && !isTokenExpired();
  }

  /// Aggiorna solo l'access token (dopo refresh)
  Future<void> updateAccessToken({
    required String accessToken,
    int expiresInSeconds = 900,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyAccessToken, accessToken);
    
    final expiry = DateTime.now().add(Duration(seconds: expiresInSeconds));
    await prefs.setInt(_keyTokenExpiry, expiry.millisecondsSinceEpoch);
  }

  /// Rimuove tutti i token (logout)
  Future<void> clearTokens() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyTokenExpiry);
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
}





