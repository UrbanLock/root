import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class DonationService {
  /// Carica tutte le donazioni dall'API admin
  static Future<List<Map<String, dynamic>>> getAllDonations() async {
    try {
      // Verifica che l'utente sia autenticato
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Non autenticato. Effettua il login prima di caricare le donazioni.');
      }

      print('DonationService: Chiamata GET /admin/donations');

      final response = await ApiClient.get('/admin/donations');

      // Log per debug
      print('DonationService: Status Code: ${response.statusCode}');
      print('DonationService: Response Body: ${response.body}');

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
        String errorMessage = 'Errore durante il caricamento delle donazioni';
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
      print('DonationService: Errore durante getAllDonations: $e');
      rethrow;
    }
  }
  /// Aggiorna lo stato di una donazione
  /// 
  /// [donationId] - ID della donazione
  /// [status] - Nuovo stato (daVisionare, inValutazione, accettata, rifiutata)
  /// [lockerId] - ID del locker (opzionale, se accettata)
  /// [cellId] - ID della cella (opzionale, se accettata)
  /// [isComunePickup] - Se il ritiro è al comune (opzionale)
  /// [motivoRifiuto] - Motivo del rifiuto (obbligatorio se status è "rifiutato")
  static Future<Map<String, dynamic>> updateDonationStatus({
    required String donationId,
    required String status,
    String? lockerId,
    String? cellId,
    bool? isComunePickup,
    String? motivoRifiuto,
  }) async {
    try {
      // Verifica che l'utente sia autenticato
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'success': false,
          'error': 'Non autenticato. Effettua il login prima di aggiornare una donazione.',
        };
      }

      // Il controller admin accetta: stato, motivoRifiuto, noteOperatore
      final body = <String, dynamic>{
        'stato': status,
      };
      
      // Se lo stato è 'rifiutato', il backend richiede motivoRifiuto
      if (status == 'rifiutato' && motivoRifiuto != null && motivoRifiuto.isNotEmpty) {
        body['motivoRifiuto'] = motivoRifiuto;
      }

      print('DonationService: Chiamata PUT /admin/donations/$donationId/status con body: $body');

      final response = await ApiClient.put(
        '/admin/donations/$donationId/status',
        body: body,
      );

      // Log per debug
      print('DonationService: Status Code: ${response.statusCode}');
      print('DonationService: Response Body: ${response.body}');
      print('DonationService: Response Headers: ${response.headers}');

      // Verifica che il body non sia vuoto
      if (response.body.isEmpty || response.body.trim().isEmpty) {
        String errorMsg = 'Risposta vuota dal server (HTTP ${response.statusCode})';
        if (response.statusCode == 404) {
          errorMsg = 'Endpoint non trovato: /donations/$donationId. Verifica che la route sia montata correttamente.';
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
        // Se il decode fallisce, prova a vedere cosa c'è nel body
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
          'donation': data['data']['donation'],
        };
      } else {
        String errorMessage = 'Errore durante l\'aggiornamento della donazione';
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
      // Gestisci errori di rete o altri errori
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

