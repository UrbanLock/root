import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/features/notifications/domain/models/app_notification.dart';
import 'package:app/features/notifications/data/repositories/notification_repository.dart';

/// Repository notifiche.
///
/// - Se è presente un [ApiClient], legge/sincronizza con il backend.
/// - Mantiene comunque una lista locale di notifiche generate dall'app
///   (promemoria, eventi locali) che non esistono sul backend.
class NotificationRepositoryImpl implements NotificationRepository {
  final ApiClient? _apiClient;

  NotificationRepositoryImpl({ApiClient? apiClient}) : _apiClient = apiClient;

  // Notifiche locali in memoria (create dall'app)
  final List<AppNotification> _localNotifications = [];

  @override
  Future<List<AppNotification>> getNotifications() async {
    List<AppNotification> remote = [];

    if (_apiClient != null) {
      try {
        final response = await _apiClient!.get(
          ApiConfig.notificationsEndpoint,
          requireAuth: true,
        );
        final items = response['items'] as List<dynamic>? ?? [];
        remote = items
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      } on ApiException catch (_) {
        // In caso di errore backend, mostra comunque le notifiche locali
      }
    }

    final all = [...remote, ..._localNotifications];
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  @override
  Future<List<AppNotification>> getUnreadNotifications() async {
    final all = await getNotifications();
    return all.where((n) => !n.isRead).toList();
  }

  @override
  Future<void> addNotification(AppNotification notification) async {
    // Notifiche generate dall'app restano solo in locale
    _localNotifications.add(notification);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    if (_apiClient != null) {
      try {
        await _apiClient!.put(
          '${ApiConfig.notificationsEndpoint}/$notificationId/read',
          requireAuth: true,
        );
      } on ApiException catch (_) {
        // In caso di errore, continuiamo comunque ad aggiornare lato client
      }
    }

    for (var i = 0; i < _localNotifications.length; i++) {
      if (_localNotifications[i].id == notificationId) {
        final n = _localNotifications[i];
        _localNotifications[i] = AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          timestamp: n.timestamp,
          type: n.type,
          isRead: true,
          payload: n.payload,
        );
      }
    }
  }

  @override
  Future<void> markAllAsRead() async {
    if (_apiClient != null) {
      try {
        final all = await getNotifications();
        for (final n in all.where((n) => !n.isRead)) {
          await markAsRead(n.id);
        }
      } catch (_) {
        // Ignora errori backend
      }
    } else {
      for (int i = 0; i < _localNotifications.length; i++) {
        if (!_localNotifications[i].isRead) {
          final n = _localNotifications[i];
          _localNotifications[i] = AppNotification(
            id: n.id,
            title: n.id,
            body: n.body,
            timestamp: n.timestamp,
            type: n.type,
            isRead: true,
            payload: n.payload,
          );
        }
      }
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    if (_apiClient != null) {
      try {
        await _apiClient!.delete(
          '${ApiConfig.notificationsEndpoint}/$notificationId',
          requireAuth: true,
        );
      } on ApiException catch (_) {
        // Ignora errori backend
      }
    }

    _localNotifications.removeWhere((n) => n.id == notificationId);
  }

  @override
  Future<void> deleteAllNotifications() async {
    if (_apiClient != null) {
      try {
        final all = await getNotifications();
        for (final n in all) {
          await deleteNotification(n.id);
        }
      } catch (_) {
        // Ignora errori backend
      }
    }

    _localNotifications.clear();
  }

  @override
  Future<int> getUnreadCount() async {
    if (_apiClient != null) {
      try {
        final response = await _apiClient!.get(
          ApiConfig.notificationsUnreadEndpoint,
          requireAuth: true,
        );
        // Backend: { success: true, data: { items: [...], pagination: {...} } }
        final items = response['items'] as List<dynamic>? ?? [];
        return items.length;
      } catch (_) {
        // In caso di errore, fallback su conteggio locale
      }
    }
    return _localNotifications.where((n) => !n.isRead).length;
  }
}


