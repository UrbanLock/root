import 'package:app/core/api/api_client.dart';
import 'package:app/core/auth/auth_service.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';
import 'package:app/features/cells/data/repositories/cell_repository_mock.dart';
import 'package:app/features/cells/data/repositories/cell_repository_impl.dart';
import 'package:app/features/lockers/data/repositories/locker_repository_impl.dart';
import 'package:app/features/lockers/data/repositories/locker_repository_mock.dart';
import 'package:app/features/lockers/domain/repositories/locker_repository.dart';
import 'package:app/features/notifications/data/repositories/notification_repository.dart';
import 'package:app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:app/features/profile/data/repositories/donation_repository.dart';
import 'package:app/features/profile/data/repositories/donation_repository_impl.dart';
import 'package:app/features/reports/data/repositories/report_repository.dart';
import 'package:app/features/reports/data/repositories/report_repository_impl.dart';

/// Dependency Injection per l'app
/// 
/// Gestisce l'inizializzazione e l'iniezione delle dipendenze
class AppDependencies {
  static const bool useMockData = false; // Usa repository reali

  // Singleton instances
  static ApiClient? _apiClient;
  static AuthService? _authService;
  static AuthRepository? _authRepository;
  static DonationRepository? _donationRepository;
  static NotificationRepository? _notificationRepository;
  static ReportRepository? _reportRepository;

  /// Inizializza le dipendenze (chiamare all'avvio dell'app)
  static Future<void> initialize() async {
    if (_apiClient != null || useMockData) return;

    // Inizializza AuthService (singleton basato su SharedPreferences)
    _authService = await AuthService.getInstance();

    // Crea ApiClient condiviso
    _apiClient = ApiClient(
      baseUrl: ApiConfig.baseUrl,
      timeout: ApiConfig.timeout,
      authService: _authService!,
    );

    // Repository autenticazione
    _authRepository = AuthRepositoryImpl(apiClient: _apiClient!);

    // Repository donazioni
    _donationRepository = DonationRepositoryImpl(apiClient: _apiClient!);

    // Repository notifiche (sincronizza con backend quando possibile)
    _notificationRepository =
        NotificationRepositoryImpl(apiClient: _apiClient);

    // Repository segnalazioni
    _reportRepository = ReportRepositoryImpl(apiClient: _apiClient!);
  }

  /// Repository per i lockers
  static LockerRepository get lockerRepository {
    if (useMockData) {
      return LockerRepositoryMock();
    } else {
      // In test o se initialize() non è stato chiamato, evita crash e usa mock.
      final client = _apiClient;
      if (client == null) {
        return LockerRepositoryMock();
      }
      return LockerRepositoryImpl(apiClient: client);
    }
  }

  /// Repository per l'autenticazione
  static AuthRepository? get authRepository {
    if (useMockData) {
      return null; // Mock auth non implementato
    }
    return _authRepository;
  }

  /// Servizio di autenticazione
  static AuthService? get authService {
    if (useMockData) {
      return null;
    }
    return _authService;
  }

  /// Client API
  static ApiClient? get apiClient {
    if (useMockData) {
      return null;
    }
    return _apiClient;
  }

  /// Repository per gestire le celle attive
  /// 
  /// **Nota**: Il repository mock è un singleton per mantenere i dati in memoria
  static CellRepository? get cellRepository {
    if (useMockData || _apiClient == null) {
      return CellRepositoryMock(); // fallback mock
    }
    return CellRepositoryImpl(apiClient: _apiClient!);
  }

  /// Repository donazioni
  static DonationRepository get donationRepository {
    if (_donationRepository != null) return _donationRepository!;
    if (_apiClient == null) {
      throw StateError(
        'AppDependencies non inizializzato: chiama initialize() in main()',
      );
    }
    _donationRepository = DonationRepositoryImpl(apiClient: _apiClient!);
    return _donationRepository!;
  }

  /// Repository notifiche
  static NotificationRepository get notificationRepository {
    if (_notificationRepository != null) return _notificationRepository!;
    if (_apiClient == null) {
      throw StateError(
        'AppDependencies non inizializzato: chiama initialize() in main()',
      );
    }
    _notificationRepository =
        NotificationRepositoryImpl(apiClient: _apiClient);
    return _notificationRepository!;
  }

  /// Repository segnalazioni
  static ReportRepository get reportRepository {
    if (_reportRepository != null) return _reportRepository!;
    if (_apiClient == null) {
      throw StateError(
        'AppDependencies non inizializzato: chiama initialize() in main()',
      );
    }
    _reportRepository = ReportRepositoryImpl(apiClient: _apiClient!);
    return _reportRepository!;
  }
}

