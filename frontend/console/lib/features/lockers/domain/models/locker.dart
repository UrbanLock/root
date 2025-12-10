import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/features/lockers/domain/models/locker_cell.dart';
import 'package:console/features/lockers/domain/models/cell_type.dart';

class Locker {
  final String id;
  final String name;
  final String code; // Codice del locker
  final LockerType type;
  final int totalCells;
  final int availableCells;
  final bool isActive;
  final bool isOnline; // Stato online/offline
  final String? description;
  final List<LockerCell>? cells;
  final LockerCellStats? cellStats;

  const Locker({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.totalCells,
    required this.availableCells,
    this.isActive = true,
    this.isOnline = true,
    this.description,
    this.cells,
    this.cellStats,
  });

  double get availabilityPercentage =>
      totalCells > 0 ? (availableCells / totalCells) * 100 : 0;

  List<LockerCell> getCellsByType(CellType cellType) {
    if (cells == null) return [];
    return cells!.where((cell) => cell.type == cellType && cell.isAvailable).toList();
  }

  bool hasAvailableCells(CellType cellType) {
    return getCellsByType(cellType).isNotEmpty;
  }
}

