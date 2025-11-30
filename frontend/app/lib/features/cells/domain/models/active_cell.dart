/// Modello per una cella attiva
/// 
/// Questo modello rappresenta una cella che l'utente sta attualmente utilizzando.
/// Può essere di due tipi:
/// - deposited: L'utente ha depositato qualcosa nella cella
/// - borrowed: L'utente ha preso qualcosa in prestito dalla cella
class ActiveCell {
  final String id;
  final String lockerId;
  final String lockerName;
  final String lockerType;
  final String cellNumber;
  final String cellId; // ID univoco della cella nel backend
  final DateTime startTime;
  final DateTime? endTime; // Null se non ha scadenza
  final CellUsageType type;
  
  ActiveCell({
    required this.id,
    required this.lockerId,
    required this.lockerName,
    required this.lockerType,
    required this.cellNumber,
    required this.cellId,
    required this.startTime,
    this.endTime,
    required this.type,
  });
  
  /// Crea un'istanza da JSON (per quando il backend sarà pronto)
  /// 
  /// **TODO**: Implementare quando il backend fornirà i dati in formato JSON
  /// ```dart
  /// factory ActiveCell.fromJson(Map<String, dynamic> json) {
  ///   return ActiveCell(
  ///     id: json['id'],
  ///     lockerId: json['locker_id'],
  ///     lockerName: json['locker_name'],
  ///     lockerType: json['locker_type'],
  ///     cellNumber: json['cell_number'],
  ///     cellId: json['cell_id'],
  ///     startTime: DateTime.parse(json['start_time']),
  ///     endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
  ///     type: CellUsageType.values.firstWhere(
  ///       (e) => e.toString() == json['type'],
  ///       orElse: () => CellUsageType.deposited,
  ///     ),
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
  ///     'locker_id': lockerId,
  ///     'locker_name': lockerName,
  ///     'locker_type': lockerType,
  ///     'cell_number': cellNumber,
  ///     'cell_id': cellId,
  ///     'start_time': startTime.toIso8601String(),
  ///     'end_time': endTime?.toIso8601String(),
  ///     'type': type.toString(),
  ///   };
  /// }
  /// ```
  
  /// Formatta la data di inizio per la visualizzazione
  String get formattedStartTime {
    final now = DateTime.now();
    final difference = now.difference(startTime);
    
    if (difference.inDays == 0) {
      return 'Oggi, ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ieri, ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${startTime.day}/${startTime.month}/${startTime.year}';
    }
  }
  
  /// Formatta il tempo rimanente fino alla scadenza
  String? get formattedEndTime {
    if (endTime == null) return null;
    
    final now = DateTime.now();
    final difference = endTime!.difference(now);
    
    if (difference.isNegative) {
      return 'Scaduto';
    }
    
    if (difference.inHours > 0) {
      return 'Scade tra ${difference.inHours}h ${difference.inMinutes % 60}min';
    } else {
      return 'Scade tra ${difference.inMinutes}min';
    }
  }
}

/// Tipo di utilizzo della cella
enum CellUsageType {
  deposited, // L'utente ha depositato qualcosa
  borrowed, // L'utente ha preso qualcosa in prestito
}

