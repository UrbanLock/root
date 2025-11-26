import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';

/// Repository per gestire i lockers
/// Questa interfaccia permette di switchare facilmente tra mock e implementazione reale
abstract class LockerRepository {
  /// Ottiene tutti i lockers disponibili
  Future<List<Locker>> getLockers();

  /// Ottiene i lockers filtrati per tipologia
  Future<List<Locker>> getLockersByType(LockerType type);

  /// Ottiene un locker specifico per ID
  Future<Locker?> getLockerById(String id);

  /// Cerca lockers per nome o descrizione
  Future<List<Locker>> searchLockers(String query);
}


