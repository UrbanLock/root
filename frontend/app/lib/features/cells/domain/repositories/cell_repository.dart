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
  
  /// Richiede una nuova cella per depositare un oggetto
  /// 
  /// **Endpoint backend**: POST /api/v1/cells/request
  /// **Body**: { "locker_id": "...", "type": "deposited", "photo": "base64..." }
  /// **Autenticazione**: Richiesta
  /// **Risposta**: { "success": true, "cell": { ... } }
  Future<ActiveCell> requestCell(String lockerId, {String? photoBase64});
}


