import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class OperatorAuthService {
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(
        '/auth/operator/login',
        body: {
          'username': username,
          'password': password,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Salva i token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'access_token',
          data['data']['tokens']['accessToken'],
        );
        await prefs.setString(
          'refresh_token',
          data['data']['tokens']['refreshToken'],
        );

        return {
          'success': true,
          'user': data['data']['user'],
        };
      } else {
        // Gestisci il formato errore dall'errorHandler
        String errorMessage = 'Errore durante il login';
        if (data['error'] != null) {
          if (data['error'] is Map) {
            errorMessage = data['error']['message'] ?? errorMessage;
          } else if (data['error'] is String) {
            errorMessage = data['error'];
          }
        } else if (data['message'] != null) {
          errorMessage = data['message'];
        }
        
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Errore di connessione: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await ApiClient.get('/auth/me');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'user': data['data']['user'],
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Errore durante il recupero dei dati utente',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Errore di connessione: ${e.toString()}',
      };
    }
  }

  static Future<bool> logout() async {
    try {
      final response = await ApiClient.post('/auth/logout');

      // Rimuovi i token anche se la chiamata fallisce
      await ApiClient.clearTokens();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return true; // Considera il logout riuscito anche se la chiamata fallisce
    } catch (e) {
      // Rimuovi i token anche in caso di errore
      await ApiClient.clearTokens();
      return true;
    }
  }

  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    return accessToken != null && accessToken.isNotEmpty;
  }
}

