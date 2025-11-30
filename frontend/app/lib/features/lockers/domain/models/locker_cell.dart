import 'package:app/features/lockers/domain/models/cell_type.dart';

/// Modello per una cella specifica in un locker
/// 
/// Rappresenta una singola cella con le sue caratteristiche
class LockerCell {
  final String id;
  final String cellNumber; // Es. "Cella 1", "Cella A-3"
  final CellType type;
  final CellSize size; // Dimensione della cella
  final bool isAvailable;
  final String? itemName; // Nome dell'oggetto (se tipo borrow o pickup)
  final String? itemDescription; // Descrizione dell'oggetto
  final String? itemImageUrl; // URL immagine oggetto (se disponibile)
  final double pricePerHour; // Prezzo per ora (basato sulla dimensione)
  final double pricePerDay; // Prezzo per giorno (basato sulla dimensione)
  final String? storeName; // Nome del negozio (se tipo pickup)
  final DateTime? availableUntil; // Fino a quando è disponibile (per pickup)
  final Duration? borrowDuration; // Durata del prestito (se tipo borrow)

  const LockerCell({
    required this.id,
    required this.cellNumber,
    required this.type,
    required this.size,
    required this.isAvailable,
    required this.pricePerHour,
    required this.pricePerDay,
    this.itemName,
    this.itemDescription,
    this.itemImageUrl,
    this.storeName,
    this.availableUntil,
    this.borrowDuration, // Durata predefinita per il prestito (es. 7 giorni)
  });

  /// Crea un'istanza da JSON (per quando il backend sarà pronto)
  /// 
  /// **TODO**: Implementare quando il backend fornirà i dati in formato JSON
  /// ```dart
  /// factory LockerCell.fromJson(Map<String, dynamic> json) {
  ///   return LockerCell(
  ///     id: json['id'],
  ///     cellNumber: json['cell_number'],
  ///     type: CellType.values.firstWhere(
  ///       (e) => e.toString() == json['type'],
  ///       orElse: () => CellType.deposit,
  ///     ),
  ///     isAvailable: json['is_available'],
  ///     itemName: json['item_name'],
  ///     itemDescription: json['item_description'],
  ///     itemImageUrl: json['item_image_url'],
  ///     pricePerHour: json['price_per_hour']?.toDouble(),
  ///     pricePerDay: json['price_per_day']?.toDouble(),
  ///     storeName: json['store_name'],
  ///     availableUntil: json['available_until'] != null 
  ///         ? DateTime.parse(json['available_until']) 
  ///         : null,
  ///   );
  /// }
  /// ```
  
  /// Converte l'istanza in JSON (per quando invieremo dati al backend)
  /// 
  /// **TODO**: Implementare quando invieremo dati al backend
  /// ```dart
  /// Map<String, dynamic> toJson() {
  ///   return {
  ///     'id': id,
  ///     'cell_number': cellNumber,
  ///     'type': type.toString(),
  ///     'is_available': isAvailable,
  ///     'item_name': itemName,
  ///     'item_description': itemDescription,
  ///     'item_image_url': itemImageUrl,
  ///     'price_per_hour': pricePerHour,
  ///     'price_per_day': pricePerDay,
  ///     'store_name': storeName,
  ///     'available_until': availableUntil?.toIso8601String(),
  ///   };
  /// }
  /// ```
}

/// Statistiche delle celle disponibili per tipo in un locker
class LockerCellStats {
  final int totalCells;
  final int availableBorrowCells; // Celle con oggetti da prendere in prestito
  final int availableDepositCells; // Celle vuote per depositare
  final int availablePickupCells; // Celle con prodotti da ritirare

  const LockerCellStats({
    required this.totalCells,
    required this.availableBorrowCells,
    required this.availableDepositCells,
    required this.availablePickupCells,
  });

  int get totalAvailable => availableBorrowCells + availableDepositCells + availablePickupCells;
}

