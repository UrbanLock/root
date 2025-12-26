import 'package:flutter/foundation.dart';
import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';
import 'dart:convert';

class CellRepositoryImpl implements CellRepository {
  final ApiClient _apiClient;

  CellRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<ActiveCell>> getActiveCells() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.activeCellsEndpoint,
        requireAuth: true,
      );

      final cellsList = response['cells'] as List<dynamic>? ?? [];
      return cellsList
          .map((e) => ActiveCell.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento celle attive: ${e.message}');
    }
  }

  @override
  Future<List<ActiveCell>> getHistory({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.historyEndpoint,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
        requireAuth: true,
      );

      final cellsList = response['cells'] as List<dynamic>? ?? [];
      return cellsList
          .map((e) => ActiveCell.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento storico celle: ${e.message}');
    }
  }

  @override
  Future<ActiveCell> requestCell(
    String lockerId, {
    required String type,
    String? photoBase64,
    Map<String, dynamic>? geolocation,
  }) async {
    try {
      final body = <String, dynamic>{
        'lockerId': lockerId,
        'type': type,
      };

      if (photoBase64 != null && photoBase64.isNotEmpty) {
        body['photo'] = photoBase64;
      }
      if (geolocation != null && geolocation.isNotEmpty) {
        body['geolocalizzazione'] = geolocation;
      }

      final response = await _apiClient.post(
        ApiConfig.requestCellEndpoint,
        body: body,
        requireAuth: true,
      );

      final cellJson = response['cell'] as Map<String, dynamic>?;
      if (cellJson == null) {
        throw Exception('Formato risposta richiesta cella non riconosciuto');
      }
      return ActiveCell.fromJson(cellJson);
    } on ApiException catch (e) {
      throw Exception('Errore nella richiesta della cella: ${e.message}');
    }
  }

  @override
  Future<void> openCell(String cellId, {String? photoBase64}) async {
    try {
      final body = <String, dynamic>{
        'cell_id': cellId,
      };
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        body['photo'] = photoBase64;
      }

      await _apiClient.post(
        ApiConfig.openCellEndpoint,
        body: body,
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw Exception('Errore nell\'apertura della cella: ${e.message}');
    }
  }

  @override
  Future<void> notifyCellClosed(String cellId) async {
    try {
      final body = <String, dynamic>{
        'cell_id': cellId,
        'door_closed': true,
      };

      await _apiClient.post(
        ApiConfig.closeCellEndpoint,
        body: body,
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw Exception('Errore nella chiusura della cella: ${e.message}');
    }
  }

  @override
  Future<void> returnCell(String cellId, {String? photoBase64}) async {
    try {
      final body = <String, dynamic>{
        'cell_id': cellId,
      };
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        body['photo'] = photoBase64;
      }

      await _apiClient.post(
        '/cells/return',
        body: body,
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw Exception('Errore nella restituzione della cella: ${e.message}');
    }
  }

  @override
  Future<BluetoothPairingResult> verifyBluetoothPairing({
    required String lockerId,
    required String cellId,
    required String bluetoothUuid,
    int? bluetoothRssi,
    String? deviceName,
    Map<String, dynamic>? geolocation,
  }) async {
    try {
      final body = <String, dynamic>{
        'lockerId': lockerId,
        'cellId': cellId,
        'bluetoothUuid': bluetoothUuid,
      };

      if (bluetoothRssi != null) {
        body['bluetoothRssi'] = bluetoothRssi;
      }
      if (deviceName != null && deviceName.isNotEmpty) {
        body['deviceName'] = deviceName;
      }
      if (geolocation != null && geolocation.isNotEmpty) {
        body['geolocation'] = geolocation;
      }

      debugPrint('📤 [API] Invio richiesta verifyBluetoothPairing: lockerId=$lockerId, cellId=$cellId, bluetoothUuid=$bluetoothUuid');
      
      final response = await _apiClient.post(
        ApiConfig.verifyBluetoothPairingEndpoint,
        body: body,
        requireAuth: true,
      );

      debugPrint('📥 [API] Risposta ricevuta: $response');

      // Verifica che la risposta sia un Map
      if (response is! Map<String, dynamic>) {
        debugPrint('❌ [API] Risposta non è un Map: ${response.runtimeType}');
        return BluetoothPairingResult(
          verified: false,
          reason: 'invalid_response',
          message: 'Formato risposta non valido dal server',
        );
      }

      // Prova a parsare la risposta, gestendo errori di parsing
      try {
        final result = BluetoothPairingResult.fromJson(response);
        debugPrint('✅ [API] Parsing riuscito: verified=${result.verified}, pairingId=${result.pairingId}, reason=${result.reason}');
        return result;
      } catch (e) {
        debugPrint('❌ [API] Errore parsing: $e');
        debugPrint('❌ [API] Response data: $response');
        
        // Se il parsing fallisce ma verified è false, restituisci comunque il risultato
        if (response['verified'] == false) {
          debugPrint('⚠️ [API] verified=false, restituisco risultato con dati disponibili');
          return BluetoothPairingResult(
            verified: false,
            reason: response['reason'] as String? ?? 'parse_error',
            message: response['message'] as String? ?? 'Errore nella lettura della risposta del server.',
          );
        }
        // Se verified è true ma il parsing fallisce, è un errore critico
        debugPrint('❌ [API] verified=true ma parsing fallito, errore critico');
        return BluetoothPairingResult(
          verified: false,
          reason: 'parse_error',
          message: 'Errore nella lettura della risposta del server. Riprova più tardi.',
        );
      }
    } on ApiException catch (e) {
      // Se il backend restituisce errore 400 con formato { success: false, data: {...} }
      // estrai i dati dall'errorData se disponibile
      debugPrint('❌ [API ERROR] Status: ${e.statusCode}, Message: ${e.message}');
      debugPrint('❌ [API ERROR] ErrorData: ${e.errorData}');
      
      if (e.isBadRequest() && e.errorData != null) {
        try {
          // Il backend restituisce errori 400 con data: { verified: false, reason: ..., message: ... }
          final errorData = e.errorData!;
          debugPrint('✅ [API ERROR] Usando errorData: reason=${errorData['reason']}, message=${errorData['message']}');
          return BluetoothPairingResult(
            verified: false,
            reason: errorData['reason'] as String? ?? 'validation_error',
            message: errorData['message'] as String? ?? e.message,
          );
        } catch (parseError) {
          debugPrint('❌ [API ERROR] Errore parsing errorData: $parseError');
          // Se il parsing fallisce, usa il messaggio dell'eccezione
        }
      }
      
      // Per altri errori API, crea risultato con verified: false
      debugPrint('⚠️ [API ERROR] Usando messaggio generico: ${e.message}');
      return BluetoothPairingResult(
        verified: false,
        reason: e.isBadRequest() ? 'validation_error' : 'api_error',
        message: e.message,
      );
    } on ConnectionException catch (e) {
      // Errore di connessione
      return BluetoothPairingResult(
        verified: false,
        reason: 'connection_error',
        message: 'Errore di connessione. Verifica la tua connessione internet e riprova.',
      );
    } on FormatException catch (e) {
      // Errore di parsing JSON
      return BluetoothPairingResult(
        verified: false,
        reason: 'parse_error',
        message: 'Errore nella lettura della risposta del server. Riprova più tardi.',
      );
    } catch (e) {
      // Altri errori generici
      debugPrint('❌ [ERROR] Errore imprevisto durante verifica Bluetooth pairing: $e');
      return BluetoothPairingResult(
        verified: false,
        reason: 'unknown_error',
        message: 'Errore durante la verifica. Riprova più tardi.',
      );
    }
  }

  @override
  Future<void> openCellWithPairing({
    required String pairingId,
    required String cellId,
    required String lockerId,
  }) async {
    try {
      final body = <String, dynamic>{
        'pairingId': pairingId,
        'cellId': cellId,
        'lockerId': lockerId,
      };

      await _apiClient.post(
        ApiConfig.openCellEndpoint,
        body: body,
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw Exception('Errore nell\'apertura della cella: ${e.message}');
    }
  }
}


