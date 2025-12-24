import 'dart:convert';

import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/features/reports/data/repositories/report_repository.dart';
import 'package:app/features/reports/domain/models/report.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ApiClient _apiClient;

  ReportRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<Report>> getReports() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.reportsEndpoint,
        requireAuth: true,
      );

      final items = response['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => Report.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento delle segnalazioni: ${e.message}');
    }
  }

  @override
  Future<Report> getReportById(String id) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.reportsEndpoint}/$id',
        requireAuth: true,
      );

      final reportJson = response['report'] as Map<String, dynamic>?;
      if (reportJson == null) {
        throw Exception('Formato risposta dettaglio segnalazione non riconosciuto');
      }
      return Report.fromJson(reportJson);
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento della segnalazione: ${e.message}');
    }
  }

  @override
  Future<Report> createReport({
    String? lockerId,
    String? cellId,
    required String category,
    required String description,
    String? base64Photo,
  }) async {
    try {
      final body = <String, dynamic>{
        'category': category,
        'description': description,
      };
      if (lockerId != null) body['lockerId'] = lockerId;
      if (cellId != null) body['cellId'] = cellId;
      if (base64Photo != null && base64Photo.isNotEmpty) {
        body['photo'] = base64Photo;
      }

      final response = await _apiClient.post(
        ApiConfig.reportsEndpoint,
        body: body,
        requireAuth: true,
      );

      final reportJson = response['report'] as Map<String, dynamic>?;
      if (reportJson == null) {
        throw Exception('Formato risposta creazione segnalazione non riconosciuto');
      }
      return Report.fromJson(reportJson);
    } on ApiException catch (e) {
      throw Exception('Errore nella creazione della segnalazione: ${e.message}');
    }
  }

  @override
  Future<Report> updateReport(
    String id, {
    String? category,
    String? description,
    String? base64Photo,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (category != null) body['category'] = category;
      if (description != null) body['description'] = description;
      if (base64Photo != null && base64Photo.isNotEmpty) {
        body['photo'] = base64Photo;
      }

      final response = await _apiClient.put(
        '${ApiConfig.reportsEndpoint}/$id',
        body: body.isEmpty ? null : body,
        requireAuth: true,
      );

      final reportJson = response['report'] as Map<String, dynamic>?;
      if (reportJson == null) {
        throw Exception('Formato risposta aggiornamento segnalazione non riconosciuto');
      }
      return Report.fromJson(reportJson);
    } on ApiException catch (e) {
      throw Exception('Errore nell\'aggiornamento della segnalazione: ${e.message}');
    }
  }

  @override
  Future<void> deleteReport(String id) async {
    try {
      await _apiClient.delete(
        '${ApiConfig.reportsEndpoint}/$id',
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw Exception('Errore nella cancellazione della segnalazione: ${e.message}');
    }
  }
}

import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/features/reports/data/repositories/report_repository.dart';
import 'package:app/features/reports/domain/models/report.dart';

/// Implementazione reale del repository delle segnalazioni.
///
/// Si appoggia agli endpoint:
/// - GET    /api/v1/reports
/// - POST   /api/v1/reports
/// - PUT    /api/v1/reports/:id
/// - DELETE /api/v1/reports/:id
class ReportRepositoryImpl implements ReportRepository {
  final ApiClient _apiClient;

  ReportRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<Report>> getReports({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.reportsEndpoint,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
        requireAuth: true,
      );

      final items = response['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => Report.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception(
          'Errore nel caricamento delle segnalazioni: ${e.message}');
    }
  }

  @override
  Future<Report> createReport({
    String? lockerId,
    String? cellId,
    required String category,
    required String description,
    String? base64Photo,
  }) async {
    try {
      final body = <String, dynamic>{
        'categoria': category,
        'descrizione': description,
      };

      if (lockerId != null && lockerId.isNotEmpty) {
        body['lockerId'] = lockerId;
      }
      if (cellId != null && cellId.isNotEmpty) {
        body['cellaId'] = cellId;
      }
      if (base64Photo != null && base64Photo.isNotEmpty) {
        body['photo'] = base64Photo;
      }

      final response = await _apiClient.post(
        ApiConfig.reportsEndpoint,
        body: body,
        requireAuth: true,
      );

      final reportJson = response['report'] as Map<String, dynamic>?;
      if (reportJson == null) {
        throw Exception(
            'Formato risposta creazione segnalazione non riconosciuto');
      }
      return Report.fromJson(reportJson);
    } on ApiException catch (e) {
      throw Exception(
          'Errore nella creazione della segnalazione: ${e.message}');
    }
  }

  @override
  Future<Report> updateReport({
    required String id,
    String? category,
    String? description,
    String? base64Photo,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (category != null) body['categoria'] = category;
      if (description != null) body['descrizione'] = description;
      if (base64Photo != null && base64Photo.isNotEmpty) {
        body['photo'] = base64Photo;
      }

      final response = await _apiClient.put(
        '${ApiConfig.reportsEndpoint}/$id',
        body: body.isEmpty ? null : body,
        requireAuth: true,
      );

      final reportJson = response['report'] as Map<String, dynamic>?;
      if (reportJson == null) {
        throw Exception(
            'Formato risposta aggiornamento segnalazione non riconosciuto');
      }
      return Report.fromJson(reportJson);
    } on ApiException catch (e) {
      throw Exception(
          'Errore nell\'aggiornamento della segnalazione: ${e.message}');
    }
  }

  @override
  Future<void> deleteReport(String id) async {
    try {
      await _apiClient.delete(
        '${ApiConfig.reportsEndpoint}/$id',
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw Exception(
          'Errore nella cancellazione della segnalazione: ${e.message}');
    }
  }
}


