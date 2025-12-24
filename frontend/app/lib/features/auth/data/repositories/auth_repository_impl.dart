import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/models/user.dart';

/// Implementazione reale del repository di autenticazione
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;

  AuthRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<LoginResponse> login({
    required String codiceFiscale,
    required String tipoAutenticazione,
    String? nome,
    String? cognome,
  }) async {
    try {
      final body = <String, dynamic>{
        'codiceFiscale': codiceFiscale.toUpperCase(),
        'tipoAutenticazione': tipoAutenticazione,
      };

      if (nome != null && nome.isNotEmpty) {
        body['nome'] = nome;
      }
      if (cognome != null && cognome.isNotEmpty) {
        body['cognome'] = cognome;
      }

      final response = await _apiClient.post(
        '/auth/login',
        body: body,
        requireAuth: false,
      );

      // Backend restituisce { user: {...}, tokens: {...} }
      final user = User.fromJson(response['user'] as Map<String, dynamic>);
      final tokens = response['tokens'] as Map<String, dynamic>;

      return LoginResponse(
        user: user,
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
        expiresIn: tokens['expiresIn'] as int,
      );
    } on ApiException catch (e) {
      if (e.isBadRequest()) {
        throw ValidationException(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
        requireAuth: false,
      );

      return response;
    } on ApiException catch (e) {
      if (e.isUnauthorized()) {
        throw UnauthorizedException('Refresh token non valido o scaduto');
      }
      rethrow;
    }
  }

  @override
  Future<User> getMe() async {
    try {
      final response = await _apiClient.get(
        '/auth/me',
        requireAuth: true,
      );

      return User.fromJson(response['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isUnauthorized()) {
        throw UnauthorizedException('Non autenticato');
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post(
        '/auth/logout',
        requireAuth: true,
      );
    } on ApiException catch (e) {
      // Anche se fallisce, consideriamo il logout completato
      // (potrebbe essere già scaduto il token)
      if (!e.isUnauthorized()) {
        rethrow;
      }
    }
  }

  @override
  Future<void> acceptTerms({String? version}) async {
    try {
      final body = <String, dynamic>{};
      if (version != null && version.isNotEmpty) {
        body['version'] = version;
      }

      await _apiClient.post(
        '/auth/accept-terms',
        body: body.isEmpty ? null : body,
        requireAuth: true,
      );
    } on ApiException catch (e) {
      // In caso di errore, rilanciamo un'eccezione generica per gestirla a livello UI se serve
      throw Exception('Errore nella registrazione dell\'accettazione dei termini: ${e.message}');
    }
  }
}

/// Eccezione per errori di autenticazione
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  
  @override
  String toString() => 'UnauthorizedException: $message';
}




