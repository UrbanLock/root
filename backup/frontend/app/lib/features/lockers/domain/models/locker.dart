import 'package:latlong2/latlong.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';

class Locker {
  final String id;
  final String name;
  final LatLng position;
  final LockerType type;
  final int totalCells;
  final int availableCells;
  final bool isActive;
  final String? description;

  const Locker({
    required this.id,
    required this.name,
    required this.position,
    required this.type,
    required this.totalCells,
    required this.availableCells,
    this.isActive = true,
    this.description,
  });

  double get availabilityPercentage =>
      totalCells > 0 ? (availableCells / totalCells) * 100 : 0;
}


