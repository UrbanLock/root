import 'dart:async';
import 'package:console/features/lockers/domain/models/locker.dart';
import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/features/lockers/domain/models/locker_cell.dart';
import 'package:console/features/lockers/domain/repositories/locker_repository.dart';
import 'package:console/features/lockers/data/mock_lockers.dart';
import 'package:console/features/lockers/data/mock_locker_cells.dart';

class LockerRepositoryMock implements LockerRepository {
  static const Duration _apiDelay = Duration(milliseconds: 300);

  @override
  Future<List<Locker>> getLockers() async {
    await Future.delayed(_apiDelay);
    return mockLockers.where((l) => l.isActive).toList();
  }

  @override
  Future<List<Locker>> getLockersByType(LockerType type) async {
    await Future.delayed(_apiDelay);
    return mockLockers
        .where((l) => l.isActive && l.type == type)
        .toList();
  }

  @override
  Future<Locker?> getLockerById(String id) async {
    await Future.delayed(_apiDelay);
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
    
    final lowerQuery = query.toLowerCase();
    return mockLockers
        .where((l) =>
            l.isActive &&
            (l.name.toLowerCase().contains(lowerQuery) ||
                l.code.toLowerCase().contains(lowerQuery) ||
                l.type.label.toLowerCase().contains(lowerQuery) ||
                (l.description?.toLowerCase().contains(lowerQuery) ?? false)))
        .toList();
  }

  @override
  Future<List<LockerCell>> getLockerCells(String lockerId) async {
    await Future.delayed(_apiDelay);
    final locker = await getLockerById(lockerId);
    if (locker == null) {
      return [];
    }
    return generateMockCells(lockerId, locker.totalCells);
  }

  @override
  Future<LockerCellStats> getLockerCellStats(String lockerId) async {
    await Future.delayed(_apiDelay);
    final cells = await getLockerCells(lockerId);
    return calculateCellStats(cells);
  }
}

