import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/cell_type.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';
import 'package:app/features/lockers/data/mock_lockers.dart';

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

/// Determina la specializzazione del locker in base al nome/ID
/// Restituisce una lista di CellType supportati
List<CellType> _getLockerSpecialization(String lockerId) {
  // Locker solo deposito
  if (lockerId.contains('deposit') && !lockerId.contains('mixed')) {
    return [CellType.deposit];
  }
  
  // Locker solo prestito
  if (lockerId.contains('borrow') && !lockerId.contains('mixed')) {
    return [CellType.borrow];
  }
  
  // Locker solo ritiro
  if (lockerId.contains('pickup') && !lockerId.contains('mixed')) {
    return [CellType.pickup];
  }
  
  // Locker misti
  if (lockerId.contains('mixed')) {
    if (lockerId.contains('pers-mixed')) {
      // Personali misti: deposit + borrow
      return [CellType.deposit, CellType.borrow];
    } else if (lockerId.contains('sport-mixed')) {
      // Sportivi misti: borrow + deposit
      return [CellType.borrow, CellType.deposit];
    } else if (lockerId.contains('comm-mixed')) {
      // Commerciali misti: pickup + deposit
      return [CellType.pickup, CellType.deposit];
    } else if (lockerId.contains('hub-mixed')) {
      // Hub completo: tutte e tre
      return [CellType.borrow, CellType.deposit, CellType.pickup];
    }
  }
  
  // Fallback: distribuzione standard (non dovrebbe mai arrivare qui)
  return [CellType.deposit, CellType.borrow, CellType.pickup];
}

/// Genera celle mock per un locker in base alla sua specializzazione
List<LockerCell> generateMockCells(String lockerId, int totalCells) {
  final cells = <LockerCell>[];
  final specialization = _getLockerSpecialization(lockerId);
  
  // Trova il locker per ottenere il tipo
  final locker = mockLockers.firstWhere(
    (l) => l.id == lockerId,
    orElse: () => mockLockers.first,
  );
  
  int cellNumber = 1;
  final sizes = [CellSize.small, CellSize.medium, CellSize.large, CellSize.extraLarge];
  
  // Distribuisci le celle in base alla specializzazione
  if (specialization.length == 1) {
    // Locker specializzato: 100% di un solo tipo
    final cellType = specialization.first;
    _generateCellsForType(cells, lockerId, cellType, totalCells, sizes, locker.type, cellNumber);
  } else if (specialization.length == 2) {
    // Locker misto: 70% tipo principale, 30% tipo secondario
    final primaryType = specialization.first;
    final secondaryType = specialization.last;
    final primaryCount = (totalCells * 0.7).round();
    final secondaryCount = totalCells - primaryCount;
    
    cellNumber = _generateCellsForType(
      cells, lockerId, primaryType, primaryCount, sizes, locker.type, cellNumber,
    );
    _generateCellsForType(
      cells, lockerId, secondaryType, secondaryCount, sizes, locker.type, cellNumber,
    );
  } else {
    // Locker con 3 tipi: 50% principale, 30% secondario, 20% terziario
    final primaryType = specialization[0];
    final secondaryType = specialization[1];
    final tertiaryType = specialization[2];
    final primaryCount = (totalCells * 0.5).round();
    final secondaryCount = (totalCells * 0.3).round();
    final tertiaryCount = totalCells - primaryCount - secondaryCount;
    
    cellNumber = _generateCellsForType(
      cells, lockerId, primaryType, primaryCount, sizes, locker.type, cellNumber,
    );
    cellNumber = _generateCellsForType(
      cells, lockerId, secondaryType, secondaryCount, sizes, locker.type, cellNumber,
    );
    _generateCellsForType(
      cells, lockerId, tertiaryType, tertiaryCount, sizes, locker.type, cellNumber,
    );
  }
  
  return cells;
}

/// Genera celle per un tipo specifico
int _generateCellsForType(
  List<LockerCell> cells,
  String lockerId,
  CellType cellType,
  int count,
  List<CellSize> sizes,
  LockerType lockerType,
  int startCellNumber,
) {
  int cellNumber = startCellNumber;
  
  if (cellType == CellType.deposit) {
    // Celle per depositare (diverse dimensioni con prezzi diversi)
    for (int i = 0; i < count; i++) {
      final size = sizes[i % sizes.length];
      final prices = _cellPrices[size]!;
      cells.add(LockerCell(
        id: '${lockerId}_cell_$cellNumber',
        cellNumber: 'Cella $cellNumber',
        type: CellType.deposit,
        size: size,
        isAvailable: i < count * 0.7, // 70% disponibili
        pricePerHour: prices['hour']!,
        pricePerDay: prices['day']!,
      ));
      cellNumber++;
    }
  } else if (cellType == CellType.borrow) {
    // Celle con oggetti da prendere in prestito
    final borrowItems = _getBorrowItemsForLockerType(lockerType);
    
    for (int i = 0; i < count; i++) {
      final item = borrowItems[i % borrowItems.length];
      cells.add(LockerCell(
        id: '${lockerId}_cell_$cellNumber',
        cellNumber: 'Cella $cellNumber',
        type: CellType.borrow,
        size: item['size'] as CellSize,
        isAvailable: i < count * 0.6, // 60% disponibili
        pricePerHour: 0.0, // Prestito gratuito
        pricePerDay: 0.0,
        itemName: item['name'] as String,
        itemDescription: item['description'] as String,
        borrowDuration: item['duration'] as Duration,
      ));
      cellNumber++;
    }
  } else if (cellType == CellType.pickup) {
    // Celle per ritirare prodotti
    final stores = [
      'Panificio Trentino',
      'Farmacia Centrale',
      'Libreria Universitaria',
      'Negozio Sport',
      'Fioreria Duomo',
      'Pasticceria Dolce Vita',
      'Erboristeria Naturale',
      'Tabaccheria Centrale',
    ];
    
    for (int i = 0; i < count; i++) {
      final store = stores[i % stores.length];
      final size = sizes[i % sizes.length];
      cells.add(LockerCell(
        id: '${lockerId}_cell_$cellNumber',
        cellNumber: 'Cella $cellNumber',
        type: CellType.pickup,
        size: size,
        isAvailable: i < count * 0.5, // 50% disponibili
        pricePerHour: 0.0, // Ritiro gratuito
        pricePerDay: 0.0,
        storeName: store,
        itemName: 'Ordine #${1000 + i}',
        availableUntil: DateTime.now().add(Duration(hours: 24 + (i * 2))),
      ));
      cellNumber++;
    }
  }
  
  return cellNumber;
}

/// Ottiene gli oggetti da prestito in base al tipo di locker
List<Map<String, dynamic>> _getBorrowItemsForLockerType(LockerType lockerType) {
  switch (lockerType) {
    case LockerType.sportivi:
      return [
        {'name': 'Palla da calcio', 'description': 'Palla da calcio professionale', 'size': CellSize.small, 'duration': const Duration(days: 7)},
        {'name': 'Racchetta da tennis', 'description': 'Racchetta da tennis con corde', 'size': CellSize.medium, 'duration': const Duration(days: 7)},
        {'name': 'Pallone da basket', 'description': 'Pallone da basket ufficiale', 'size': CellSize.small, 'duration': const Duration(days: 7)},
        {'name': 'Corda per saltare', 'description': 'Corda per esercizi fitness', 'size': CellSize.small, 'duration': const Duration(days: 7)},
        {'name': 'Yoga mat', 'description': 'Tappetino yoga antiscivolo', 'size': CellSize.medium, 'duration': const Duration(days: 7)},
        {'name': 'Pesi manubri', 'description': 'Set manubri 2-5 kg', 'size': CellSize.medium, 'duration': const Duration(days: 3)},
      ];
    
    case LockerType.petFriendly:
      return [
        {'name': 'Ciotola per acqua', 'description': 'Ciotola portatile per cani', 'size': CellSize.small, 'duration': const Duration(days: 7)},
        {'name': 'Gioco per cani', 'description': 'Pallina o frisbee', 'size': CellSize.small, 'duration': const Duration(days: 7)},
        {'name': 'Sacchetti igienici', 'description': 'Confezione sacchetti biodegradabili', 'size': CellSize.small, 'duration': const Duration(days: 14)},
        {'name': 'Guinzaglio extra', 'description': 'Guinzaglio di ricambio', 'size': CellSize.small, 'duration': const Duration(days: 7)},
        {'name': 'Asciugamano per animali', 'description': 'Asciugamano per pulizia zampe', 'size': CellSize.small, 'duration': const Duration(days: 7)},
      ];
    
    case LockerType.cicloturistici:
      return [
        {'name': 'Kit riparazione', 'description': 'Kit completo per riparazioni bici', 'size': CellSize.small, 'duration': const Duration(days: 3)},
        {'name': 'Pompa portatile', 'description': 'Pompa per gonfiare gomme', 'size': CellSize.small, 'duration': const Duration(days: 3)},
        {'name': 'Lucchetto bici', 'description': 'Lucchetto a catena', 'size': CellSize.medium, 'duration': const Duration(days: 1)},
        {'name': 'Casco', 'description': 'Casco protettivo', 'size': CellSize.medium, 'duration': const Duration(days: 1)},
        {'name': 'Borraccia', 'description': 'Borraccia termica', 'size': CellSize.small, 'duration': const Duration(days: 7)},
      ];
    
    default:
      // Per locker misti o altri tipi, oggetti generici
      return [
        {'name': 'Oggetto generico', 'description': 'Oggetto disponibile per prestito', 'size': CellSize.small, 'duration': const Duration(days: 7)},
      ];
  }
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
