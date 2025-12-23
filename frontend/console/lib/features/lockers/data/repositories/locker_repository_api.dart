import 'dart:convert';
import 'package:console/core/api/api_client.dart';
import 'package:console/features/lockers/domain/models/locker.dart';
import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/features/lockers/domain/models/locker_cell.dart';
import 'package:console/features/lockers/domain/models/cell_type.dart';
import 'package:console/features/lockers/domain/repositories/locker_repository.dart';

class LockerRepositoryApi implements LockerRepository {
  // Mapping tipo backend -> frontend
  LockerType _mapLockerType(String type) {
    switch (type) {
      case 'sportivi':
        return LockerType.sportivi;
      case 'personali':
        return LockerType.personali;
      case 'petFriendly':
        return LockerType.petFriendly;
      case 'commerciali':
        return LockerType.commerciali;
      case 'cicloturistici':
        return LockerType.cicloturistici;
      default:
        return LockerType.personali;
    }
  }

  // Mapping tipo cella backend -> frontend
  CellType _mapCellType(String type) {
    switch (type) {
      case 'deposit':
        return CellType.deposit;
      case 'borrow':
        return CellType.borrow;
      case 'pickup':
        return CellType.pickup;
      default:
        return CellType.deposit;
    }
  }

  // Mapping dimensione backend -> frontend
  CellSize _mapCellSize(String size) {
    switch (size) {
      case 'small':
        return CellSize.small;
      case 'medium':
        return CellSize.medium;
      case 'large':
        return CellSize.large;
      case 'extraLarge':
        return CellSize.extraLarge;
      default:
        return CellSize.medium;
    }
  }

  Locker _mapLockerFromJson(Map<String, dynamic> json) {
    return Locker(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['id'] as String, // Usa l'id come codice
      type: _mapLockerType(json['type'] as String),
      totalCells: json['totalCells'] as int? ?? 0,
      availableCells: json['availableCells'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      isOnline: json['online'] as bool? ?? true,
      description: json['description'] as String?,
    );
  }

  LockerCell _mapCellFromJson(Map<String, dynamic> json) {
    return LockerCell(
      id: json['id'] as String,
      cellNumber: json['cellNumber'] as String,
      type: _mapCellType(json['type'] as String),
      size: _mapCellSize(json['size'] as String),
      isAvailable: json['isAvailable'] as bool? ?? false,
      pricePerHour: (json['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      pricePerDay: (json['pricePerDay'] as num?)?.toDouble() ?? 0.0,
      itemName: json['itemName'] as String?,
      itemDescription: json['itemDescription'] as String?,
      itemImageUrl: json['itemImageUrl'] as String?,
      storeName: json['storeName'] as String?,
      availableUntil: json['availableUntil'] != null
          ? DateTime.tryParse(json['availableUntil'] as String)
          : null,
      borrowDuration: json['borrowDuration'] != null
          ? Duration(seconds: json['borrowDuration'] as int)
          : null,
    );
  }

  LockerCellStats _mapStatsFromJson(Map<String, dynamic> json) {
    return LockerCellStats(
      totalCells: json['totalCells'] as int? ?? 0,
      availableBorrowCells: json['availableBorrowCells'] as int? ?? 0,
      availableDepositCells: json['availableDepositCells'] as int? ?? 0,
      availablePickupCells: json['availablePickupCells'] as int? ?? 0,
    );
  }

  @override
  Future<List<Locker>> getLockers() async {
    try {
      final response = await ApiClient.get('/lockers');
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final lockersJson = data['data']['lockers'] as List;
        return lockersJson
            .map((json) => _mapLockerFromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Errore nel recupero dei locker');
      }
    } catch (e) {
      throw Exception('Errore di connessione: ${e.toString()}');
    }
  }

  @override
  Future<List<Locker>> getLockersByType(LockerType type) async {
    try {
      // Mappa il tipo frontend -> backend
      String typeString;
      switch (type) {
        case LockerType.sportivi:
          typeString = 'sportivi';
          break;
        case LockerType.personali:
          typeString = 'personali';
          break;
        case LockerType.petFriendly:
          typeString = 'petFriendly';
          break;
        case LockerType.commerciali:
          typeString = 'commerciali';
          break;
        case LockerType.cicloturistici:
          typeString = 'cicloturistici';
          break;
      }

      final response = await ApiClient.get(
        '/lockers',
        queryParams: {'type': typeString},
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final lockersJson = data['data']['lockers'] as List;
        return lockersJson
            .map((json) => _mapLockerFromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Errore nel recupero dei locker');
      }
    } catch (e) {
      throw Exception('Errore di connessione: ${e.toString()}');
    }
  }

  @override
  Future<Locker?> getLockerById(String id) async {
    try {
      final response = await ApiClient.get('/lockers/$id');
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return _mapLockerFromJson(data['data']['locker'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception(data['message'] ?? 'Errore nel recupero del locker');
      }
    } catch (e) {
      throw Exception('Errore di connessione: ${e.toString()}');
    }
  }

  @override
  Future<List<Locker>> searchLockers(String query) async {
    // Il backend non ha un endpoint di ricerca, quindi filtriamo lato client
    final allLockers = await getLockers();
    if (query.isEmpty) {
      return allLockers;
    }

    final lowerQuery = query.toLowerCase();
    return allLockers.where((locker) {
      return locker.name.toLowerCase().contains(lowerQuery) ||
          locker.code.toLowerCase().contains(lowerQuery) ||
          locker.type.label.toLowerCase().contains(lowerQuery) ||
          (locker.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  @override
  Future<List<LockerCell>> getLockerCells(String lockerId) async {
    try {
      final response = await ApiClient.get('/lockers/$lockerId/cells');
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final cellsJson = data['data']['cells'] as List;
        return cellsJson
            .map((json) => _mapCellFromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Errore nel recupero delle celle');
      }
    } catch (e) {
      throw Exception('Errore di connessione: ${e.toString()}');
    }
  }

  @override
  Future<LockerCellStats> getLockerCellStats(String lockerId) async {
    try {
      final response = await ApiClient.get('/lockers/$lockerId/cells/stats');
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return _mapStatsFromJson(data['data']['stats'] as Map<String, dynamic>);
      } else {
        throw Exception(data['message'] ?? 'Errore nel recupero delle statistiche');
      }
    } catch (e) {
      throw Exception('Errore di connessione: ${e.toString()}');
    }
  }
}

