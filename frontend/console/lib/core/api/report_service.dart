import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class ReportService {
  /// Carica tutte le segnalazioni dall'API admin
  static Future<List<Map<String, dynamic>>> getAllReports() async {
    try {
      // Verifica che l'utente sia autenticato
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Non autenticato. Effettua il login prima di caricare le segnalazioni.');
      }

      print('ReportService: Chiamata GET /admin/reports');

      final response = await ApiClient.get('/admin/reports');

      // Log per debug
      print('ReportService: Status Code: ${response.statusCode}');
      print('ReportService: Response Body: ${response.body}');

      // Verifica che il body non sia vuoto
      if (response.body.isEmpty || response.body.trim().isEmpty) {
        throw Exception('Risposta vuota dal server (HTTP ${response.statusCode})');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Risposta non valida dal server: ${e.toString()}');
      }

      if (response.statusCode == 200 && data['success'] == true) {
        final items = data['data']['items'] as List<dynamic>;
        return items.map((item) => item as Map<String, dynamic>).toList();
      } else {
        String errorMessage = 'Errore durante il caricamento delle segnalazioni';
        if (data['error'] != null) {
          if (data['error'] is Map && data['error']['message'] != null) {
            errorMessage = data['error']['message'];
          } else if (data['error'] is String) {
            errorMessage = data['error'];
          }
        } else if (data['message'] != null) {
          errorMessage = data['message'];
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('ReportService: Errore durante getAllReports: $e');
      rethrow;
    }
  }

  /// Aggiorna lo stato di una segnalazione
  /// 
  /// [reportId] - ID della segnalazione
  /// [status] - Nuovo stato (aperta, in_analisi, assegnata, in_lavorazione, risolta, chiusa)
  /// [rispostaOperatore] - Risposta dell'operatore (opzionale)
  /// [noteOperatore] - Note dell'operatore (opzionale)
  static Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
    String? rispostaOperatore,
    String? noteOperatore,
  }) async {
    try {
      // Verifica che l'utente sia autenticato
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'success': false,
          'error': 'Non autenticato. Effettua il login prima di aggiornare una segnalazione.',
        };
      }

      final body = <String, dynamic>{
        'stato': status,
      };

      if (rispostaOperatore != null && rispostaOperatore.isNotEmpty) {
        body['rispostaOperatore'] = rispostaOperatore;
      }

      if (noteOperatore != null && noteOperatore.isNotEmpty) {
        body['noteOperatore'] = noteOperatore;
      }

      print('ReportService: Chiamata PUT /admin/reports/$reportId/status con body: $body');

      final response = await ApiClient.put(
        '/admin/reports/$reportId/status',
        body: body,
      );

      // Log per debug
      print('ReportService: Status Code: ${response.statusCode}');
      print('ReportService: Response Body: ${response.body}');

      // Verifica che il body non sia vuoto
      if (response.body.isEmpty || response.body.trim().isEmpty) {
        String errorMsg = 'Risposta vuota dal server (HTTP ${response.statusCode})';
        if (response.statusCode == 404) {
          errorMsg = 'Endpoint non trovato: /admin/reports/$reportId/status. Verifica che la route sia montata correttamente.';
        } else if (response.statusCode == 401) {
          errorMsg = 'Non autorizzato. Verifica che il token di autenticazione sia valido.';
        } else if (response.statusCode == 500) {
          errorMsg = 'Errore interno del server. Controlla i log del backend.';
        }
        return {
          'success': false,
          'error': errorMsg,
        };
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        final bodyPreview = response.body.length > 100 
            ? '${response.body.substring(0, 100)}...' 
            : response.body;
        return {
          'success': false,
          'error': 'Risposta non valida dal server (HTTP ${response.statusCode}): $bodyPreview',
        };
      }

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'report': data['data']['report'],
        };
      } else {
        String errorMessage = 'Errore durante l\'aggiornamento della segnalazione';
        if (data['error'] != null) {
          if (data['error'] is Map && data['error']['message'] != null) {
            errorMessage = data['error']['message'];
          } else if (data['error'] is String) {
            errorMessage = data['error'];
          }
        } else if (data['message'] != null) {
          errorMessage = data['message'];
        } else if (response.statusCode != 200) {
          errorMessage = 'Errore HTTP ${response.statusCode}';
        }
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      String errorMessage = 'Errore di connessione';
      if (e is FormatException) {
        errorMessage = 'Errore nel formato della risposta: ${e.message}';
      } else {
        errorMessage = 'Errore: ${e.toString()}';
      }
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }
}

