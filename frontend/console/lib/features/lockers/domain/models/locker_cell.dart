import 'package:console/features/lockers/domain/models/cell_type.dart';

/// Modello per una cella specifica in un locker
class LockerCell {
  final String id;
  final String cellNumber;
  final CellType type;
  final CellSize size;
  final bool isAvailable;
  final String? itemName;
  final String? itemDescription;
  final String? itemImageUrl;
  final double pricePerHour;
  final double pricePerDay;
  final String? storeName;
  final DateTime? availableUntil;
  final Duration? borrowDuration;

  const LockerCell({
    required this.id,
    required this.cellNumber,
    required this.type,
    required this.size,
    required this.isAvailable,
    required this.pricePerHour,
    required this.pricePerDay,
    this.itemName,
    this.itemDescription,
    this.itemImageUrl,
    this.storeName,
    this.availableUntil,
    this.borrowDuration,
  });
}

/// Statistiche delle celle disponibili per tipo in un locker
class LockerCellStats {
  final int totalCells;
  final int availableBorrowCells;
  final int availableDepositCells;
  final int availablePickupCells;

  const LockerCellStats({
    required this.totalCells,
    required this.availableBorrowCells,
    required this.availableDepositCells,
    required this.availablePickupCells,
  });

  int get totalAvailable => availableBorrowCells + availableDepositCells + availablePickupCells;
}

