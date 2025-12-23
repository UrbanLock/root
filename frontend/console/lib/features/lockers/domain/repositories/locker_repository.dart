import 'package:console/features/lockers/domain/models/locker.dart';
import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/features/lockers/domain/models/locker_cell.dart';

abstract class LockerRepository {
  Future<List<Locker>> getLockers();
  Future<List<Locker>> getLockersByType(LockerType type);
  Future<Locker?> getLockerById(String id);
  Future<List<Locker>> searchLockers(String query);
  Future<List<LockerCell>> getLockerCells(String lockerId);
  Future<LockerCellStats> getLockerCellStats(String lockerId);
}





