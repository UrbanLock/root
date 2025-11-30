import 'package:app/features/lockers/domain/repositories/locker_repository.dart';
import 'package:app/features/lockers/data/repositories/locker_repository_mock.dart';
import 'package:app/features/lockers/data/repositories/locker_repository_impl.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';
import 'package:app/features/cells/data/repositories/cell_repository_mock.dart';

/// Dependency Injection semplice per l'app
/// 
/// Per switchare tra mock e implementazione reale, cambia il valore di `useMockData`
/// 
/// **IMPORTANTE**: Quando il backend sarà pronto:
/// 1. Cambia `useMockData` a `false`
/// 2. Implementa i metodi in `LockerRepositoryImpl` con le chiamate HTTP reali
/// 3. Aggiungi la dipendenza `http` in pubspec.yaml se necessario
/// 4. Configura l'URL base del backend
class AppDependencies {
  static const bool useMockData = true; // Cambia a false quando il backend è pronto

  static LockerRepository get lockerRepository {
    if (useMockData) {
      return LockerRepositoryMock();
    } else {
      return LockerRepositoryImpl();
    }
  }

  /// Repository per gestire le celle attive
  /// 
  /// **TODO quando il backend sarà pronto:**
  /// 1. Creare CellRepositoryImpl che implementa le chiamate HTTP reali
  /// 2. Cambiare useMockData a false
  /// 3. Configurare ApiClient con l'URL del backend
  static CellRepository? get cellRepository {
    if (useMockData) {
      return CellRepositoryMock();
    } else {
      // TODO: Implementare CellRepositoryImpl quando il backend sarà pronto
      // return CellRepositoryImpl(apiClient: ApiClient(baseUrl: ApiConfig.baseUrl));
      return null; // Per ora null, da implementare
    }
  }
}

