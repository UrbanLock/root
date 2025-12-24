/// Modello per una cella attiva
/// 
/// Questo modello rappresenta una cella che l'utente sta attualmente utilizzando.
/// Può essere di tre tipi:
/// - deposited: L'utente ha depositato qualcosa nella cella
/// - borrowed: L'utente ha preso qualcosa in prestito dalla cella
/// - pickup: L'utente ha un ordine da ritirare da un negozio locale
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

  /// Crea un'istanza da JSON restituito dal backend.
  factory ActiveCell.fromJson(Map<String, dynamic> json) {
    return ActiveCell(
      id: json['id'] as String,
      lockerId: json['lockerId'] as String,
      lockerName: json['lockerName'] as String,
      lockerType: json['lockerType'] as String,
      cellNumber: json['cellNumber'] as String,
      cellId: json['cellId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      type: CellUsageType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['type'] as String? ?? ''),
        orElse: () => CellUsageType.deposited,
      ),
    );
  }

  /// Converte l'istanza in JSON per l'invio al backend.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lockerId': lockerId,
      'lockerName': lockerName,
      'lockerType': lockerType,
      'cellNumber': cellNumber,
      'cellId': cellId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'type': type.toString().split('.').last,
    };
  }
  
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
  pickup, // L'utente ha un ordine da ritirare da un negozio locale
}

