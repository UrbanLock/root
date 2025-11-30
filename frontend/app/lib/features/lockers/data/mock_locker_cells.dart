import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/cell_type.dart';

/// Mock data per le celle di un locker
/// 
/// **TODO quando il backend sarà pronto:**
/// - Caricare celle dal backend (GET /api/v1/lockers/:id/cells)
/// - Aggiornare disponibilità in tempo reale
/// - Gestire prenotazioni e prestiti

/// Prezzi per dimensione (per ora/giorno)
Map<CellSize, Map<String, double>> _cellPrices = {
  CellSize.small: {'hour': 0.30, 'day': 5.00},
  CellSize.medium: {'hour': 0.50, 'day': 8.00},
  CellSize.large: {'hour': 0.80, 'day': 12.00},
  CellSize.extraLarge: {'hour': 1.20, 'day': 18.00},
};

/// Genera celle mock per un locker
List<LockerCell> generateMockCells(String lockerId, int totalCells) {
  final cells = <LockerCell>[];
  
  // Distribuzione approssimativa:
  // - 40% celle per depositare (a pagamento)
  // - 30% celle con oggetti da prendere in prestito
  // - 30% celle per ritirare prodotti
  
  final depositCount = (totalCells * 0.4).round();
  final borrowCount = (totalCells * 0.3).round();
  final pickupCount = totalCells - depositCount - borrowCount;
  
  int cellNumber = 1;
  final sizes = [CellSize.small, CellSize.medium, CellSize.large, CellSize.extraLarge];
  
  // Celle per depositare (diverse dimensioni con prezzi diversi)
  for (int i = 0; i < depositCount; i++) {
    final size = sizes[i % sizes.length];
    final prices = _cellPrices[size]!;
    cells.add(LockerCell(
      id: '${lockerId}_cell_$cellNumber',
      cellNumber: 'Cella $cellNumber',
      type: CellType.deposit,
      size: size,
      isAvailable: i < depositCount * 0.7, // 70% disponibili
      pricePerHour: prices['hour']!,
      pricePerDay: prices['day']!,
    ));
    cellNumber++;
  }
  
  // Celle con oggetti da prendere in prestito
  final borrowItems = [
    {'name': 'Palla da calcio', 'description': 'Palla da calcio professionale', 'size': CellSize.small},
    {'name': 'Racchetta da tennis', 'description': 'Racchetta da tennis con corde', 'size': CellSize.medium},
    {'name': 'Pallone da basket', 'description': 'Pallone da basket ufficiale', 'size': CellSize.small},
    {'name': 'Corda per saltare', 'description': 'Corda per esercizi fitness', 'size': CellSize.small},
    {'name': 'Yoga mat', 'description': 'Tappetino yoga antiscivolo', 'size': CellSize.medium},
  ];
  
  for (int i = 0; i < borrowCount; i++) {
    final item = borrowItems[i % borrowItems.length];
    cells.add(LockerCell(
      id: '${lockerId}_cell_$cellNumber',
      cellNumber: 'Cella $cellNumber',
      type: CellType.borrow,
      size: item['size'] as CellSize,
      isAvailable: i < borrowCount * 0.6, // 60% disponibili
      pricePerHour: 0.0, // Prestito gratuito
      pricePerDay: 0.0,
      itemName: item['name'] as String,
      itemDescription: item['description'] as String,
      borrowDuration: const Duration(days: 7), // Prestito di 7 giorni
    ));
    cellNumber++;
  }
  
  // Celle per ritirare prodotti
  final stores = [
    'Panificio Trentino',
    'Farmacia Centrale',
    'Libreria Universitaria',
    'Negozio Sport',
    'Fioreria Duomo',
  ];
  
  for (int i = 0; i < pickupCount; i++) {
    final store = stores[i % stores.length];
    final size = sizes[i % sizes.length];
    cells.add(LockerCell(
      id: '${lockerId}_cell_$cellNumber',
      cellNumber: 'Cella $cellNumber',
      type: CellType.pickup,
      size: size,
      isAvailable: i < pickupCount * 0.5, // 50% disponibili
      pricePerHour: 0.0, // Ritiro gratuito
      pricePerDay: 0.0,
      storeName: store,
      itemName: 'Ordine #${1000 + i}',
      availableUntil: DateTime.now().add(Duration(hours: 24 + (i * 2))),
    ));
    cellNumber++;
  }
  
  return cells;
}

/// Calcola le statistiche delle celle
LockerCellStats calculateCellStats(List<LockerCell> cells) {
  return LockerCellStats(
    totalCells: cells.length,
    availableBorrowCells: cells.where((c) => c.type == CellType.borrow && c.isAvailable).length,
    availableDepositCells: cells.where((c) => c.type == CellType.deposit && c.isAvailable).length,
    availablePickupCells: cells.where((c) => c.type == CellType.pickup && c.isAvailable).length,
  );
}

