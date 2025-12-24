import 'package:app/features/auth/domain/models/user.dart';

/// Repository per gestire l'autenticazione
abstract class AuthRepository {
  /// Effettua il login con codice fiscale
  /// 
  /// [codiceFiscale] deve essere di 16 caratteri alfanumerici
  /// [tipoAutenticazione] deve essere 'spid' o 'cie'
  /// [nome] e [cognome] sono opzionali (usati solo per nuovi utenti)
  Future<LoginResponse> login({
    required String codiceFiscale,
    required String tipoAutenticazione,
    String? nome,
    String? cognome,
  });

  /// Aggiorna l'access token usando il refresh token
  Future<Map<String, dynamic>> refreshToken(String refreshToken);

  /// Ottiene le informazioni dell'utente corrente
  /// Richiede autenticazione
  Future<User> getMe();

  /// Effettua il logout
  /// Richiede autenticazione
  Future<void> logout();

  /// Registra l'accettazione dei termini di utilizzo / privacy sul backend
  /// Richiede autenticazione
  Future<void> acceptTerms({String? version});
}




