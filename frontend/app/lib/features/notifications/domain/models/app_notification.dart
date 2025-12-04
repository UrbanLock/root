/// Modello per una notifica dell'app
/// 
/// Rappresenta una notifica visualizzata nella pagina notifiche dell'app
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? payload; // Dati aggiuntivi (es. ID cella, ID locker, ecc.)

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.payload,
  });

  /// Crea una notifica da una notifica locale del sistema
  factory AppNotification.fromLocalNotification({
    required String id,
    required String title,
    required String body,
    required DateTime timestamp,
    String? payload,
  }) {
    NotificationType type = NotificationType.info;
    
    // Determina il tipo in base al payload o al contenuto
    if (payload != null) {
      if (payload.startsWith('open_cell_') || payload.startsWith('reminder_cell_')) {
        type = NotificationType.warning;
      } else if (payload.startsWith('expiring_cell_')) {
        type = NotificationType.warning;
      } else if (payload.startsWith('expired_cell_')) {
        type = NotificationType.error;
      } else if (payload.startsWith('closed_cell_')) {
        type = NotificationType.success;
      }
    }

    return AppNotification(
      id: id,
      title: title,
      body: body,
      timestamp: timestamp,
      type: type,
      payload: payload,
    );
  }

  /// Formatta la data per la visualizzazione
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Adesso';
        }
        return '${difference.inMinutes} min fa';
      }
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Tipo di notifica
enum NotificationType {
  info,      // Informazione generica
  warning,   // Avviso (es. cella aperta, in scadenza)
  error,     // Errore (es. cella scaduta)
  success,   // Successo (es. cella chiusa)
}


