import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/repositories/locker_repository.dart';

/// Implementazione reale del repository con chiamate HTTP al backend
class LockerRepositoryImpl implements LockerRepository {
  final ApiClient _apiClient;

  LockerRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Converte LockerType enum in stringa per il backend
  String _lockerTypeToString(LockerType type) {
    switch (type) {
      case LockerType.sportivi:
        return 'sportivi';
      case LockerType.personali:
        return 'personali';
      case LockerType.petFriendly:
        return 'petFriendly';
      case LockerType.commerciali:
        return 'commerciali';
      case LockerType.cicloturistici:
        return 'cicloturistici';
    }
  }

  @override
  Future<List<Locker>> getLockers() async {
    try {
      final response = await _apiClient.get(
        '/lockers',
        requireAuth: false,
      );

      final lockersList = response['lockers'] as List<dynamic>;
      return lockersList
          .map((json) => Locker.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento lockers: ${e.message}');
    }
  }

  @override
  Future<List<Locker>> getLockersByType(LockerType type) async {
    try {
      final typeString = _lockerTypeToString(type);
      final response = await _apiClient.get(
        '/lockers',
        queryParameters: {'type': typeString},
        requireAuth: false,
      );

      final lockersList = response['lockers'] as List<dynamic>;
      return lockersList
          .map((json) => Locker.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento lockers per tipo: ${e.message}');
    }
  }

  @override
  Future<Locker?> getLockerById(String id) async {
    try {
      final response = await _apiClient.get(
        '/lockers/$id',
        requireAuth: false,
      );

      final lockerJson = response['locker'] as Map<String, dynamic>;
      return Locker.fromJson(lockerJson);
    } on ApiException catch (e) {
      if (e.isNotFound()) {
        return null;
      }
      throw Exception('Errore nel caricamento locker: ${e.message}');
    }
  }

  @override
  Future<List<Locker>> searchLockers(String query) async {
    // Il backend non ha endpoint di ricerca, quindi carichiamo tutti i lockers
    // e filtriamo lato client
    if (query.isEmpty) {
      return getLockers();
    }

    try {
      final allLockers = await getLockers();
      final lowerQuery = query.toLowerCase();
      
      return allLockers.where((locker) {
        final nameMatch = locker.name.toLowerCase().contains(lowerQuery);
        final descMatch = locker.description?.toLowerCase().contains(lowerQuery) ?? false;
        return nameMatch || descMatch;
      }).toList();
    } catch (e) {
      throw Exception('Errore nella ricerca lockers: $e');
    }
  }

  @override
  Future<List<LockerCell>> getLockerCells(String lockerId) async {
    try {
      final response = await _apiClient.get(
        '/lockers/$lockerId/cells',
        requireAuth: false,
      );

      final cellsList = response['cells'] as List<dynamic>;
      return cellsList
          .map((json) => LockerCell.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      if (e.isNotFound()) {
        throw Exception('Locker non trovato: $lockerId');
      }
      throw Exception('Errore nel caricamento celle: ${e.message}');
    }
  }

  @override
  Future<LockerCellStats> getLockerCellStats(String lockerId) async {
    try {
      final response = await _apiClient.get(
        '/lockers/$lockerId/cells/stats',
        requireAuth: false,
      );

      return LockerCellStats.fromJson(response);
    } on ApiException catch (e) {
      if (e.isNotFound()) {
        throw Exception('Locker non trovato: $lockerId');
      }
      throw Exception('Errore nel caricamento statistiche: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> getLockerBluetoothInfo(String lockerId) async {
    try {
      final response = await _apiClient.get(
        '/lockers/$lockerId/bluetooth-info',
        requireAuth: true,
      );

      return response as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.isNotFound()) {
        throw Exception('Locker non trovato: $lockerId');
      }
      
      // Controlla se l'errore indica che il locker non ha UUID Bluetooth configurato
      // Il backend restituisce: "Locker {id} non ha UUID Bluetooth configurato. Contattare l'amministratore."
      final errorMessage = e.message.toLowerCase();
      if (errorMessage.contains('uuid bluetooth') && 
          (errorMessage.contains('non ha') || 
           errorMessage.contains('non configurato') ||
           errorMessage.contains('not configured'))) {
        throw BluetoothNotConfiguredException(
          lockerId,
          message: e.message,
        );
      }
      
      throw Exception('Errore nel caricamento info Bluetooth: ${e.message}');
    }
  }
}


