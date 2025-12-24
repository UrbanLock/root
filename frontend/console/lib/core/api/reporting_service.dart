import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class ReportingService {
  /// Carica report utilizzo
  /// 
  /// [periodo] - 'giorno', 'settimana', 'mese', 'anno'
  /// [tipologia] - tipo locker (opzionale)
  /// [postazione] - lockerId specifico (opzionale)
  /// [lockerType] - tipo locker (opzionale)
  static Future<Map<String, dynamic>> getUsageReport({
    String periodo = 'mese',
    String? tipologia,
    String? postazione,
    String? lockerType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Non autenticato. Effettua il login prima di caricare i report.');
      }

      final queryParams = <String, String>{
        'periodo': periodo,
      };
      
      if (tipologia != null) {
        queryParams['tipologia'] = tipologia;
      }
      if (postazione != null) {
        queryParams['postazione'] = postazione;
      }
      if (lockerType != null) {
        queryParams['lockerType'] = lockerType;
      }

      print('ReportingService: Chiamata GET /admin/reporting/usage con query: $queryParams');

      final response = await ApiClient.get('/admin/reporting/usage', queryParams: queryParams);

      print('ReportingService: Status Code: ${response.statusCode}');
      print('ReportingService: Response Body: ${response.body}');

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
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        String errorMessage = 'Errore durante il caricamento del report';
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
      print('ReportingService: Errore durante getUsageReport: $e');
      rethrow;
    }
  }

  /// Carica parchi più popolari
  /// 
  /// [periodo] - 'giorno', 'settimana', 'mese', 'anno'
  /// [limit] - numero massimo di risultati (default: 10)
  static Future<Map<String, dynamic>> getPopularParks({
    String periodo = 'mese',
    int limit = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Non autenticato. Effettua il login prima di caricare i report.');
      }

      final queryParams = <String, String>{
        'periodo': periodo,
        'limit': limit.toString(),
      };

      print('ReportingService: Chiamata GET /admin/reporting/popular-parks con query: $queryParams');

      final response = await ApiClient.get('/admin/reporting/popular-parks', queryParams: queryParams);

      print('ReportingService: Status Code: ${response.statusCode}');
      print('ReportingService: Response Body: ${response.body}');

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
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        String errorMessage = 'Errore durante il caricamento dei parchi popolari';
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
      print('ReportingService: Errore durante getPopularParks: $e');
      rethrow;
    }
  }

  /// Carica categorie più richieste
  /// 
  /// [periodo] - 'giorno', 'settimana', 'mese', 'anno'
  static Future<Map<String, dynamic>> getPopularCategories({
    String periodo = 'mese',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Non autenticato. Effettua il login prima di caricare i report.');
      }

      final queryParams = <String, String>{
        'periodo': periodo,
      };

      print('ReportingService: Chiamata GET /admin/reporting/popular-categories con query: $queryParams');

      final response = await ApiClient.get('/admin/reporting/popular-categories', queryParams: queryParams);

      print('ReportingService: Status Code: ${response.statusCode}');
      print('ReportingService: Response Body: ${response.body}');

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
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        String errorMessage = 'Errore durante il caricamento delle categorie popolari';
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
      print('ReportingService: Errore durante getPopularCategories: $e');
      rethrow;
    }
  }

  /// Carica analisi comparativa tipologie locker
  /// 
  /// [periodo] - 'giorno', 'settimana', 'mese', 'anno'
  /// [tipologie] - lista di tipologie locker da confrontare (opzionale)
  static Future<Map<String, dynamic>> getComparisonReport({
    String periodo = 'mese',
    List<String>? tipologie,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Non autenticato. Effettua il login prima di caricare i report.');
      }

      final queryParams = <String, String>{
        'periodo': periodo,
      };
      
      if (tipologie != null && tipologie.isNotEmpty) {
        queryParams['tipologie'] = tipologie.join(',');
      }

      print('ReportingService: Chiamata GET /admin/reporting/comparison con query: $queryParams');

      final response = await ApiClient.get('/admin/reporting/comparison', queryParams: queryParams);

      print('ReportingService: Status Code: ${response.statusCode}');
      print('ReportingService: Response Body: ${response.body}');

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
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        String errorMessage = 'Errore durante il caricamento del report comparativo';
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
      print('ReportingService: Errore durante getComparisonReport: $e');
      rethrow;
    }
  }
}

