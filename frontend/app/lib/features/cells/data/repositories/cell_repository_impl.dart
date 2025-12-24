import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';

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

      final items = response['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => ActiveCell.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento delle celle attive: ${e.message}');
    }
  }

  @override
  Future<void> openCell(String cellId, {String? photoBase64}) async {
    try {
      final body = <String, dynamic>{'cell_id': cellId};
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
      await _apiClient.post(
        ApiConfig.closeCellEndpoint,
        body: {
          'cell_id': cellId,
          'door_closed': true,
        },
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw Exception('Errore nella chiusura della cella: ${e.message}');
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

      final items = response['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => ActiveCell.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento dello storico celle: ${e.message}');
    }
  }

  @override
  Future<ActiveCell> requestCell(String lockerId,
      {String? photoBase64}) async {
    try {
      final body = <String, dynamic>{
        'lockerId': lockerId,
        'type': 'deposited',
      };
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        body['photo'] = photoBase64;
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
      throw Exception('Errore nella richiesta di una cella: ${e.message}');
    }
  }
}

import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';

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
  Future<ActiveCell> requestCell(String lockerId, {String? photoBase64}) async {
    try {
      final body = <String, dynamic>{
        'lockerId': lockerId,
        'type': 'deposited',
      };

      if (photoBase64 != null && photoBase64.isNotEmpty) {
        body['photo'] = photoBase64;
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
}


