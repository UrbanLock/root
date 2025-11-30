import 'dart:async';
import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/repositories/locker_repository.dart';
import 'package:app/features/lockers/data/mock_lockers.dart';
import 'package:app/features/lockers/data/mock_locker_cells.dart';

/// Implementazione mock del repository
/// Simula chiamate API con delay per testare l'app senza backend
class LockerRepositoryMock implements LockerRepository {
  // Simula il delay di una chiamata API reale (in millisecondi)
  static const Duration _apiDelay = Duration(milliseconds: 500);

  @override
  Future<List<Locker>> getLockers() async {
    // Simula chiamata API
    await Future.delayed(_apiDelay);
    
    // In un'implementazione reale, qui faremmo:
    // final response = await http.get(Uri.parse('$baseUrl/api/lockers'));
    // return (response.data as List).map((json) => Locker.fromJson(json)).toList();
    
    return mockLockers.where((l) => l.isActive).toList();
  }

  @override
  Future<List<Locker>> getLockersByType(LockerType type) async {
    await Future.delayed(_apiDelay);
    
    // Simula: GET /api/lockers?type=sportivi
    return mockLockers
        .where((l) => l.isActive && l.type == type)
        .toList();
  }

  @override
  Future<Locker?> getLockerById(String id) async {
    await Future.delayed(_apiDelay);
    
    // Simula: GET /api/lockers/:id
    try {
      return mockLockers.firstWhere((l) => l.id == id && l.isActive);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Locker>> searchLockers(String query) async {
    await Future.delayed(_apiDelay);
    
    if (query.isEmpty) {
      return getLockers();
    }
    
    // Simula: GET /api/lockers/search?q=query
    final lowerQuery = query.toLowerCase();
    return mockLockers
        .where((l) =>
            l.isActive &&
            (l.name.toLowerCase().contains(lowerQuery) ||
                (l.description?.toLowerCase().contains(lowerQuery) ?? false)))
        .toList();
  }

  @override
  Future<List<LockerCell>> getLockerCells(String lockerId) async {
    await Future.delayed(_apiDelay);
    
    // TODO: Quando il backend sarà pronto:
    // final response = await http.get(Uri.parse('$baseUrl/api/lockers/$lockerId/cells'));
    // return (response.data['cells'] as List)
    //     .map((json) => LockerCell.fromJson(json))
    //     .toList();
    
    // Trova il locker per ottenere il numero totale di celle
    final locker = mockLockers.firstWhere(
      (l) => l.id == lockerId,
      orElse: () => mockLockers.first,
    );
    
    return generateMockCells(lockerId, locker.totalCells);
  }

  @override
  Future<LockerCellStats> getLockerCellStats(String lockerId) async {
    await Future.delayed(_apiDelay);
    
    // TODO: Quando il backend sarà pronto:
    // final response = await http.get(Uri.parse('$baseUrl/api/lockers/$lockerId/cells/stats'));
    // return LockerCellStats.fromJson(response.data);
    
    final cells = await getLockerCells(lockerId);
    return calculateCellStats(cells);
  }
}


