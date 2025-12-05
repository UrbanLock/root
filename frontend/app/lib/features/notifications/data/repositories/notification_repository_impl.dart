import 'package:app/features/notifications/domain/models/app_notification.dart';
import 'package:app/features/notifications/data/repositories/notification_repository.dart';

/// Implementazione mock del repository notifiche
/// 
/// **TODO quando il backend sarà pronto:**
/// - Implementare chiamate HTTP reali
/// - Sincronizzare con il server
/// - Usare database locale per cache
class NotificationRepositoryImpl implements NotificationRepository {
  // Singleton pattern per condividere la stessa lista tra tutte le istanze
  static final NotificationRepositoryImpl _instance = NotificationRepositoryImpl._internal();
  factory NotificationRepositoryImpl() => _instance;
  NotificationRepositoryImpl._internal();

  // Mock: lista notifiche in memoria
  // In produzione, questo verrà da un database locale o dal backend
  final List<AppNotification> _notifications = [];

  @override
  Future<List<AppNotification>> getNotifications() async {
    // TODO: Quando il backend sarà pronto:
    // final response = await apiClient.get(ApiConfig.notificationsEndpoint);
    // return (response['notifications'] as List)
    //     .map((json) => AppNotification.fromJson(json))
    //     .toList();
    
    // Ordina per timestamp (più recenti prima)
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.from(_notifications);
  }

  @override
  Future<List<AppNotification>> getUnreadNotifications() async {
    return _notifications.where((n) => !n.isRead).toList();
  }

  @override
  Future<void> addNotification(AppNotification notification) async {
    // TODO: Quando il backend sarà pronto:
    // await apiClient.post(ApiConfig.notificationsEndpoint, notification.toJson());
    
    _notifications.add(notification);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    // TODO: Quando il backend sarà pronto:
    // await apiClient.put('${ApiConfig.notificationsEndpoint}/$notificationId/read', {});
    
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = AppNotification(
        id: _notifications[index].id,
        title: _notifications[index].title,
        body: _notifications[index].body,
        timestamp: _notifications[index].timestamp,
        type: _notifications[index].type,
        isRead: true,
        payload: _notifications[index].payload,
      );
    }
  }

  @override
  Future<void> markAllAsRead() async {
    // TODO: Quando il backend sarà pronto:
    // await apiClient.put('${ApiConfig.notificationsEndpoint}/read-all', {});
    
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = AppNotification(
          id: _notifications[i].id,
          title: _notifications[i].title,
          body: _notifications[i].body,
          timestamp: _notifications[i].timestamp,
          type: _notifications[i].type,
          isRead: true,
          payload: _notifications[i].payload,
        );
      }
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    // TODO: Quando il backend sarà pronto:
    // await apiClient.delete('${ApiConfig.notificationsEndpoint}/$notificationId');
    
    _notifications.removeWhere((n) => n.id == notificationId);
  }

  @override
  Future<void> deleteAllNotifications() async {
    // TODO: Quando il backend sarà pronto:
    // await apiClient.delete('${ApiConfig.notificationsEndpoint}');
    
    _notifications.clear();
  }

  @override
  Future<int> getUnreadCount() async {
    return _notifications.where((n) => !n.isRead).length;
  }
}

