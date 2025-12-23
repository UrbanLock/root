import 'package:console/features/lockers/domain/models/cell_type.dart';

/// Modello per una cella specifica in un locker
class LockerCell {
  final String id;
  final String cellNumber;
  final CellType type;
  final CellSize size;
  final bool isAvailable;
  final String? stato; // 'libera', 'occupata', 'manutenzione'
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
    this.stato,
    this.itemName,
    this.itemDescription,
    this.itemImageUrl,
    this.storeName,
    this.availableUntil,
    this.borrowDuration,
  });

  LockerCell copyWith({
    String? id,
    String? cellNumber,
    CellType? type,
    CellSize? size,
    bool? isAvailable,
    String? stato,
    String? itemName,
    String? itemDescription,
    String? itemImageUrl,
    double? pricePerHour,
    double? pricePerDay,
    String? storeName,
    DateTime? availableUntil,
    Duration? borrowDuration,
  }) {
    return LockerCell(
      id: id ?? this.id,
      cellNumber: cellNumber ?? this.cellNumber,
      type: type ?? this.type,
      size: size ?? this.size,
      isAvailable: isAvailable ?? this.isAvailable,
      stato: stato ?? this.stato,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      itemName: itemName ?? this.itemName,
      itemDescription: itemDescription ?? this.itemDescription,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      storeName: storeName ?? this.storeName,
      availableUntil: availableUntil ?? this.availableUntil,
      borrowDuration: borrowDuration ?? this.borrowDuration,
    );
  }
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



