import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';

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

  /// Ottiene le celle disponibili per un locker specifico
  /// 
  /// **Endpoint backend**: GET /api/v1/lockers/:id/cells
  /// **Autenticazione**: Opzionale (alcune celle potrebbero richiedere autenticazione)
  /// **Risposta**: Lista di celle con dettagli (tipo, disponibilità, prezzi, ecc.)
  Future<List<LockerCell>> getLockerCells(String lockerId);

  /// Ottiene le statistiche delle celle per un locker
  /// 
  /// **Endpoint backend**: GET /api/v1/lockers/:id/cells/stats
  /// **Risposta**: Statistiche aggregate delle celle disponibili
  Future<LockerCellStats> getLockerCellStats(String lockerId);
}


