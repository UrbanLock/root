import 'package:app/features/cells/domain/models/active_cell.dart';

/// Repository per gestire le celle attive
/// 
/// **TODO quando il backend sarà pronto:**
/// 1. Implementare le chiamate HTTP reali in CellRepositoryImpl
/// 2. Aggiungere gestione errori
/// 3. Implementare cache locale se necessario
/// 4. Aggiungere WebSocket per aggiornamenti in tempo reale
abstract class CellRepository {
  /// Ottiene tutte le celle attive dell'utente
  /// 
  /// **Endpoint backend**: GET /api/v1/cells/active
  /// **Autenticazione**: Richiesta (Bearer token)
  /// **Risposta**: Lista di celle attive
  Future<List<ActiveCell>> getActiveCells();
  
  /// Apre una cella (richiede Bluetooth e foto se necessario)
  /// 
  /// **Endpoint backend**: POST /api/v1/cells/open
  /// **Body**: { "cell_id": "...", "photo": "base64..." (opzionale) }
  /// **Autenticazione**: Richiesta
  /// **Risposta**: { "success": true, "cell_id": "...", "door_opened": true }
  Future<void> openCell(String cellId, {String? photoBase64});
  
  /// Notifica al backend che lo sportello è stato chiuso
  /// 
  /// **Endpoint backend**: POST /api/v1/cells/close
  /// **Body**: { "cell_id": "...", "door_closed": true }
  /// **Autenticazione**: Richiesta
  /// **Risposta**: { "success": true, "cell_closed": true }
  /// 
  /// **Nota**: Questo endpoint viene chiamato automaticamente quando il backend
  /// rileva la chiusura dello sportello tramite sensori. L'app può anche chiamarlo
  /// manualmente se necessario.
  Future<void> notifyCellClosed(String cellId);
  
  /// Ottiene lo storico delle celle utilizzate
  /// 
  /// **Endpoint backend**: GET /api/v1/cells/history?page=1&limit=20
  /// **Autenticazione**: Richiesta
  /// **Risposta**: Lista paginata di celle utilizzate
  Future<List<ActiveCell>> getHistory({int page = 1, int limit = 20});
  
  /// Richiede una nuova cella (deposito / prestito / pickup)
  /// 
  /// **Endpoint backend**: POST /api/v1/cells/request
  /// **Body**: {
  ///   "lockerId": "...",
  ///   "type": "deposited" | "borrow" | "pickup",
  ///   "photo": "base64..." (opzionale),
  ///   "geolocalizzazione": { lat, lng } (opzionale)
  /// }
  /// **Autenticazione**: Richiesta
  /// **Risposta**: { "success": true, "cell": { ... } }
  Future<ActiveCell> requestCell(
    String lockerId, {
    required String type,
    String? photoBase64,
    Map<String, dynamic>? geolocation,
  });

  /// Restituisce una cella di prestito / ordine (termina il noleggio)
  ///
  /// **Endpoint backend**: POST /api/v1/cells/return
  /// **Body**: { "cell_id": "...", "photo": "base64..." (opzionale) }
  /// **Autenticazione**: Richiesta
  Future<void> returnCell(String cellId, {String? photoBase64});
  
  /// Verifica accoppiamento Bluetooth e assegna cella
  /// 
  /// **Endpoint backend**: POST /api/v1/cells/verify-bluetooth-pairing
  /// **Body**: {
  ///   "lockerId": "...",
  ///   "cellId": "...",
  ///   "bluetoothUuid": "...",
  ///   "bluetoothRssi": -45 (opzionale),
  ///   "deviceName": "..." (opzionale),
  ///   "geolocation": { "lat": ..., "lng": ... } (opzionale)
  /// }
  /// **Autenticazione**: Richiesta
  /// **Risposta**: { "verified": true, "pairingId": "...", "cellAssigned": { ... } }
  Future<BluetoothPairingResult> verifyBluetoothPairing({
    required String lockerId,
    required String cellId,
    required String bluetoothUuid,
    int? bluetoothRssi,
    String? deviceName,
    Map<String, dynamic>? geolocation,
  });
  
  /// Apre una cella usando pairingId (modificato)
  /// 
  /// **Endpoint backend**: POST /api/v1/cells/open
  /// **Body**: { "pairingId": "...", "cellId": "...", "lockerId": "..." }
  /// **Autenticazione**: Richiesta
  /// **Risposta**: { "success": true, "doorOpened": true }
  Future<void> openCellWithPairing({
    required String pairingId,
    required String cellId,
    required String lockerId,
  });
}

/// Risultato della verifica accoppiamento Bluetooth
class BluetoothPairingResult {
  final bool verified;
  final String? pairingId;
  final ActiveCell? cellAssigned;
  final String? reason;
  final String? message;
  
  BluetoothPairingResult({
    required this.verified,
    this.pairingId,
    this.cellAssigned,
    this.reason,
    this.message,
  });
  
  factory BluetoothPairingResult.fromJson(Map<String, dynamic> json) {
    // Prova a parsare cellAssigned, ma gestisci errori di parsing
    ActiveCell? cellAssigned;
    if (json['cellAssigned'] != null) {
      try {
        final cellData = json['cellAssigned'];
        if (cellData is Map<String, dynamic>) {
          cellAssigned = ActiveCell.fromJson(cellData);
        }
      } catch (e) {
        // Se il parsing fallisce, lascia cellAssigned null
        // Il risultato sarà comunque valido se verified è false
        cellAssigned = null;
      }
    }
    
    return BluetoothPairingResult(
      verified: json['verified'] as bool? ?? false,
      pairingId: json['pairingId'] as String?,
      cellAssigned: cellAssigned,
      reason: json['reason'] as String?,
      message: json['message'] as String?,
    );
  }
}


