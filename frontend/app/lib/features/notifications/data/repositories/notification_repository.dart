import 'package:app/features/notifications/domain/models/app_notification.dart';

/// Repository per gestire le notifiche dell'app
/// 
/// **TODO quando il backend sarà pronto:**
/// - Sincronizzare notifiche con il server
/// - Caricare storico notifiche dal backend
/// - Marcare notifiche come lette sul server
abstract class NotificationRepository {
  /// Ottiene tutte le notifiche
  Future<List<AppNotification>> getNotifications();

  /// Ottiene le notifiche non lette
  Future<List<AppNotification>> getUnreadNotifications();

  /// Aggiunge una nuova notifica
  Future<void> addNotification(AppNotification notification);

  /// Marca una notifica come letta
  Future<void> markAsRead(String notificationId);

  /// Marca tutte le notifiche come lette
  Future<void> markAllAsRead();

  /// Elimina una notifica
  Future<void> deleteNotification(String notificationId);

  /// Elimina tutte le notifiche
  Future<void> deleteAllNotifications();

  /// Ottiene il numero di notifiche non lette
  Future<int> getUnreadCount();
}

