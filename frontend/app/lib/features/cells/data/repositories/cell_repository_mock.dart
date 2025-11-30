import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';

/// Implementazione mock del repository per le celle
/// Simula chiamate API con delay per testare l'app senza backend
class CellRepositoryMock implements CellRepository {
  // Simula il delay di una chiamata API reale
  static const Duration _apiDelay = Duration(milliseconds: 500);
  
  // Mock data - in produzione verrà dal backend
  final List<ActiveCell> _mockActiveCells = [];
  
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
    // TODO: Quando il backend sarà pronto, sostituire con:
    // final response = await apiClient.post(
    //   ApiConfig.closeCellEndpoint,
    //   {'cell_id': cellId, 'door_closed': true},
    // );
    // if (!response['success']) {
    //   throw Exception('Failed to close cell: ${response['error']}');
    // }
    
    await Future.delayed(_apiDelay);
    
    // Rimuove la cella dalla lista mock
    _mockActiveCells.removeWhere((cell) => cell.cellId == cellId);
  }
  
  @override
  Future<List<ActiveCell>> getHistory({int page = 1, int limit = 20}) async {
    // TODO: Quando il backend sarà pronto, sostituire con:
    // final response = await apiClient.get(
    //   '${ApiConfig.historyEndpoint}?page=$page&limit=$limit',
    // );
    // return (response['cells'] as List)
    //     .map((json) => ActiveCell.fromJson(json))
    //     .toList();
    
    await Future.delayed(_apiDelay);
    return []; // Mock: lista vuota per ora
  }
  
  @override
  Future<ActiveCell> requestCell(String lockerId, {String? photoBase64}) async {
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
    final newCell = ActiveCell(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lockerId: lockerId,
      lockerName: 'Mock Locker',
      lockerType: 'Personali',
      cellNumber: 'Cella ${_mockActiveCells.length + 1}',
      cellId: 'cell_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 24)),
      type: CellUsageType.deposited,
    );
    
    _mockActiveCells.add(newCell);
    return newCell;
  }
  
  // Metodo helper per aggiungere celle mock (solo per testing)
  void addMockCell(ActiveCell cell) {
    _mockActiveCells.add(cell);
  }
}

