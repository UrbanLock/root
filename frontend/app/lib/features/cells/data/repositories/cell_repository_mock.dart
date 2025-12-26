import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';

/// Implementazione mock del repository per le celle
/// Simula chiamate API con delay per testare l'app senza backend
/// 
/// ⚠️ SOLO PER TESTING: Gestisce celle attive e storico in memoria
/// IN PRODUZIONE: Verrà sostituito con chiamate HTTP reali al backend
class CellRepositoryMock implements CellRepository {
  // Singleton instance
  static CellRepositoryMock? _instance;
  
  // Simula il delay di una chiamata API reale
  static const Duration _apiDelay = Duration(milliseconds: 500);
  
  // Mock data - in produzione verrà dal backend
  final List<ActiveCell> _mockActiveCells = [];
  final List<ActiveCell> _mockHistory = []; // Storico celle completate
  
  // Costruttore privato per singleton
  CellRepositoryMock._internal() {
    // ⚠️ SOLO PER TESTING: Aggiungi celle pickup mock all'inizializzazione
    _initializeMockPickupCells();
  }
  
  /// Factory constructor per singleton
  factory CellRepositoryMock() {
    _instance ??= CellRepositoryMock._internal();
    return _instance!;
  }
  
  /// ⚠️ SOLO PER TESTING: Inizializza celle pickup mock
  void _initializeMockPickupCells() {
    final now = DateTime.now();
    
    // Aggiungi due celle pickup mock
    _mockActiveCells.addAll([
      ActiveCell(
        id: 'pickup-mock-001',
        lockerId: 'comm-pickup-001',
        lockerName: 'Centro Commerciale',
        lockerType: 'Commerciali',
        cellNumber: 'Cella 5',
        cellId: 'cell-pickup-mock-001',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(days: 2)),
        type: CellUsageType.pickup,
      ),
      ActiveCell(
        id: 'pickup-mock-002',
        lockerId: 'comm-pickup-002',
        lockerName: 'Stazione FS',
        lockerType: 'Commerciali',
        cellNumber: 'Cella 12',
        cellId: 'cell-pickup-mock-002',
        startTime: now.subtract(const Duration(hours: 5)),
        endTime: now.add(const Duration(days: 1)),
        type: CellUsageType.pickup,
      ),
    ]);
  }
  
  @override
  Future<List<ActiveCell>> getActiveCells() async {
    // TODO: Quando il backend sarà pronto, sostituire con:
    // final response = await apiClient.get(ApiConfig.activeCellsEndpoint);
    // return (response['cells'] as List)
    //     .map((json) => ActiveCell.fromJson(json))
    //     .toList();
    
    await Future.delayed(_apiDelay);
    return List.from(_mockActiveCells);
  }
  
  @override
  Future<void> openCell(String cellId, {String? photoBase64}) async {
    // TODO: Quando il backend sarà pronto, sostituire con:
    // final response = await apiClient.post(
    //   ApiConfig.openCellEndpoint,
    //   {
    //     'cell_id': cellId,
    //     if (photoBase64 != null) 'photo': photoBase64,
    //   },
    // );
    // if (!response['success']) {
    //   throw Exception('Failed to open cell: ${response['error']}');
    // }
    
    await Future.delayed(_apiDelay);
    // Simula apertura cella
  }
  
  @override
  Future<void> notifyCellClosed(String cellId) async {
    // TODO BACKEND: Quando il backend sarà pronto, sostituire con:
    // final response = await apiClient.post(
    //   ApiConfig.closeCellEndpoint,
    //   {'cell_id': cellId, 'door_closed': true},
    // );
    // if (!response['success']) {
    //   throw Exception('Failed to close cell: ${response['error']}');
    // }
    
    await Future.delayed(_apiDelay);
    
    // ⚠️ SOLO PER TESTING: Sposta la cella dall'attive allo storico
    final cellIndex = _mockActiveCells.indexWhere((cell) => cell.cellId == cellId);
    if (cellIndex != -1) {
      final completedCell = _mockActiveCells[cellIndex];
      _mockActiveCells.removeAt(cellIndex);
      // Aggiungi allo storico
      _mockHistory.insert(0, completedCell); // Aggiungi all'inizio (più recente)
      // Limita lo storico a 100 elementi
      if (_mockHistory.length > 100) {
        _mockHistory.removeRange(100, _mockHistory.length);
      }
    }
  }
  
  @override
  Future<List<ActiveCell>> getHistory({int page = 1, int limit = 20}) async {
    // TODO BACKEND: Quando il backend sarà pronto, sostituire con:
    // final response = await apiClient.get(
    //   '${ApiConfig.historyEndpoint}?page=$page&limit=$limit',
    // );
    // return (response['cells'] as List)
    //     .map((json) => ActiveCell.fromJson(json))
    //     .toList();
    
    await Future.delayed(_apiDelay);
    
    // ⚠️ SOLO PER TESTING: Restituisce lo storico mock
    final startIndex = (page - 1) * limit;
    final endIndex = startIndex + limit;
    if (startIndex >= _mockHistory.length) {
      return [];
    }
    return _mockHistory.sublist(
      startIndex,
      endIndex > _mockHistory.length ? _mockHistory.length : endIndex,
    );
  }
  
  @override
  Future<ActiveCell> requestCell(
    String lockerId, {
    required String type,
    String? photoBase64,
    Map<String, dynamic>? geolocation,
  }) async {
    // TODO: Quando il backend sarà pronto, sostituire con:
    // final response = await apiClient.post(
    //   ApiConfig.donateEndpoint,
    //   {
    //     'locker_id': lockerId,
    //     'type': 'deposited',
    //     if (photoBase64 != null) 'photo': photoBase64,
    //   },
    // );
    // return ActiveCell.fromJson(response['cell']);
    
    await Future.delayed(_apiDelay);
    
    // Crea una nuova cella mock
    final usageType = () {
      switch (type) {
        case 'borrow':
          return CellUsageType.borrowed;
        case 'pickup':
          return CellUsageType.pickup;
        case 'deposited':
        default:
          return CellUsageType.deposited;
      }
    }();

    final newCell = ActiveCell(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lockerId: lockerId,
      lockerName: 'Mock Locker',
      lockerType: 'Personali',
      cellNumber: 'Cella ${_mockActiveCells.length + 1}',
      cellId: 'cell_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 24)),
      type: usageType,
    );
    
    _mockActiveCells.add(newCell);
    return newCell;
  }
  
  // Metodo helper per aggiungere celle mock (solo per testing)
  void addMockCell(ActiveCell cell) {
    _mockActiveCells.add(cell);
  }
  
  /// ⚠️ SOLO PER TESTING: Aggiunge una cella attiva quando viene aperta
  /// IN PRODUZIONE: Il backend aggiungerà automaticamente quando viene aperta una cella
  void addActiveCell(ActiveCell cell) {
    // Verifica che non esista già una cella con lo stesso cellId
    if (!_mockActiveCells.any((c) => c.cellId == cell.cellId)) {
      _mockActiveCells.add(cell);
    }
  }

  @override
  Future<void> returnCell(String cellId, {String? photoBase64}) async {
    // Mock: rimuove la cella dalle attive per simulare la restituzione
    _mockActiveCells.removeWhere((c) => c.cellId == cellId);
  }

  @override
  Future<BluetoothPairingResult> verifyBluetoothPairing({
    required String lockerId,
    required String cellId,
    required String bluetoothUuid,
    int? bluetoothRssi,
    String? deviceName,
    Map<String, dynamic>? geolocation,
  }) async {
    await Future.delayed(_apiDelay);
    
    // ⚠️ SOLO PER TESTING: Simula verifica accoppiamento Bluetooth
    // TODO: Quando il backend sarà pronto, sostituire con:
    // final response = await _apiClient.post(
    //   ApiConfig.verifyBluetoothPairingEndpoint,
    //   body: { ... },
    // );
    // return BluetoothPairingResult.fromJson(response);
    
    // Per testing, la verifica ha sempre successo
    // Genera un pairingId mock
    final pairingId = 'pairing-${DateTime.now().millisecondsSinceEpoch}';
    
    // Crea una cella assegnata mock
    final cellAssigned = ActiveCell(
      id: pairingId,
      lockerId: lockerId,
      lockerName: 'Mock Locker',
      lockerType: 'Personali',
      cellNumber: 'Cella ${cellId.split('-').last}',
      cellId: cellId,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(days: 7)),
      type: CellUsageType.borrowed,
    );
    
    // Aggiungi la cella alle attive
    addActiveCell(cellAssigned);
    
    return BluetoothPairingResult(
      verified: true,
      pairingId: pairingId,
      cellAssigned: cellAssigned,
      message: 'Accoppiamento verificato. Cella assegnata.',
    );
  }

  @override
  Future<void> openCellWithPairing({
    required String pairingId,
    required String cellId,
    required String lockerId,
  }) async {
    await Future.delayed(_apiDelay);
    
    // ⚠️ SOLO PER TESTING: Simula apertura cella con pairingId
    // TODO: Quando il backend sarà pronto, sostituire con:
    // await _apiClient.post(
    //   ApiConfig.openCellEndpoint,
    //   body: {
    //     'pairingId': pairingId,
    //     'cellId': cellId,
    //     'lockerId': lockerId,
    //   },
    // );
    
    // Verifica che la cella esista nelle attive (simula verifica backend)
    final cellExists = _mockActiveCells.any((c) => c.id == pairingId && c.cellId == cellId);
    if (!cellExists) {
      throw Exception('Accoppiamento non trovato o non più attivo per pairingId $pairingId');
    }
    
    // Simula apertura cella (in produzione il backend invierebbe comando al locker fisico)
  }
}

