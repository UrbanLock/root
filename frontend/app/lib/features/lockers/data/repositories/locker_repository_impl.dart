import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/repositories/locker_repository.dart';

/// Implementazione reale del repository (da usare quando il backend sarà pronto)
/// 
/// Esempio di come implementare le chiamate HTTP reali:
/// 
/// ```dart
/// class LockerRepositoryImpl implements LockerRepository {
///   final String baseUrl = 'https://api.null.app';
///   final http.Client _client;
/// 
///   LockerRepositoryImpl({http.Client? client}) 
///       : _client = client ?? http.Client();
/// 
///   @override
///   Future<List<Locker>> getLockers() async {
///     final response = await _client.get(
///       Uri.parse('$baseUrl/api/lockers'),
///       headers: {'Authorization': 'Bearer $token'},
///     );
///     
///     if (response.statusCode == 200) {
///       final data = jsonDecode(response.body);
///       return (data['lockers'] as List)
///           .map((json) => Locker.fromJson(json))
///           .toList();
///     } else {
///       throw Exception('Failed to load lockers');
///     }
///   }
/// 
///   // ... altri metodi
/// }
/// ```
class LockerRepositoryImpl implements LockerRepository {
  // TODO: Implementare quando il backend sarà pronto
  // Per ora lancia un'eccezione per indicare che non è ancora implementato
  
  @override
  Future<List<Locker>> getLockers() {
    throw UnimplementedError(
      'Backend non ancora disponibile. Usa LockerRepositoryMock per i test.',
    );
  }

  @override
  Future<List<Locker>> getLockersByType(LockerType type) {
    throw UnimplementedError(
      'Backend non ancora disponibile. Usa LockerRepositoryMock per i test.',
    );
  }

  @override
  Future<Locker?> getLockerById(String id) {
    throw UnimplementedError(
      'Backend non ancora disponibile. Usa LockerRepositoryMock per i test.',
    );
  }

  @override
  Future<List<Locker>> searchLockers(String query) {
    throw UnimplementedError(
      'Backend non ancora disponibile. Usa LockerRepositoryMock per i test.',
    );
  }

  @override
  Future<List<LockerCell>> getLockerCells(String lockerId) {
    throw UnimplementedError(
      'Backend non ancora disponibile. Usa LockerRepositoryMock per i test.',
    );
  }

  @override
  Future<LockerCellStats> getLockerCellStats(String lockerId) {
    throw UnimplementedError(
      'Backend non ancora disponibile. Usa LockerRepositoryMock per i test.',
    );
  }
}


