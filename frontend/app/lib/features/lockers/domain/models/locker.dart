import 'package:latlong2/latlong.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/cell_type.dart';

class Locker {
  final String id;
  final String name;
  final LatLng position;
  final LockerType type;
  final int totalCells;
  final int availableCells;
  final bool isActive;
  final String? description;
  final List<LockerCell>? cells; // Lista delle celle disponibili (opzionale, caricata on-demand)
  final LockerCellStats? cellStats; // Statistiche delle celle per tipo

  const Locker({
    required this.id,
    required this.name,
    required this.position,
    required this.type,
    required this.totalCells,
    required this.availableCells,
    this.isActive = true,
    this.description,
    this.cells,
    this.cellStats,
  });

  double get availabilityPercentage =>
      totalCells > 0 ? (availableCells / totalCells) * 100 : 0;

  /// Ottiene le celle disponibili per un tipo specifico
  List<LockerCell> getCellsByType(CellType cellType) {
    if (cells == null) return [];
    return cells!.where((cell) => cell.type == cellType && cell.isAvailable).toList();
  }

  /// Verifica se ci sono celle disponibili per un tipo specifico
  bool hasAvailableCells(CellType cellType) {
    return getCellsByType(cellType).isNotEmpty;
  }

  /// Crea un'istanza da JSON (risposta backend)
  factory Locker.fromJson(Map<String, dynamic> json) {
    final position = json['position'] as Map<String, dynamic>;
    final lat = (position['lat'] as num).toDouble();
    final lng = (position['lng'] as num).toDouble();

    final typeString = json['type'] as String?;
    final type = LockerType.fromString(typeString) ?? LockerType.personali;

    return Locker(
      id: json['id'] as String,
      name: json['name'] as String,
      position: LatLng(lat, lng),
      type: type,
      totalCells: json['totalCells'] as int? ?? 0,
      availableCells: json['availableCells'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      description: json['description'] as String?,
    );
  }
}


