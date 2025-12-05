import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/notifications/domain/models/app_notification.dart';
import 'package:app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:app/features/notifications/data/repositories/notification_repository.dart';

class NotificationsPage extends StatefulWidget {
  final ThemeManager themeManager;
  final VoidCallback? onNotificationsUpdated;

  const NotificationsPage({
    super.key,
    required this.themeManager,
    this.onNotificationsUpdated,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationRepository _notificationRepository = NotificationRepositoryImpl();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await _notificationRepository.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ricarica le notifiche quando la pagina diventa visibile
    _loadNotifications();
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    await _notificationRepository.markAsRead(notification.id);
    await _loadNotifications();
    widget.onNotificationsUpdated?.call();
  }

  Future<void> _markAllAsRead() async {
    await _notificationRepository.markAllAsRead();
    await _loadNotifications();
    widget.onNotificationsUpdated?.call();
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    await _notificationRepository.deleteNotification(notification.id);
    await _loadNotifications();
    widget.onNotificationsUpdated?.call();
  }

  Future<void> _deleteAllNotifications() async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Elimina tutte le notifiche'),
        content: const Text('Sei sicuro di voler eliminare tutte le notifiche?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Elimina'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _notificationRepository.deleteAllNotifications();
      await _loadNotifications();
      widget.onNotificationsUpdated?.call();
    }
  }

  Color _getNotificationColor(NotificationType type, bool isDark) {
    switch (type) {
      case NotificationType.success:
        return CupertinoColors.systemGreen;
      case NotificationType.warning:
        return CupertinoColors.systemOrange;
      case NotificationType.error:
        return CupertinoColors.systemRed;
      case NotificationType.info:
      default:
        return AppColors.primary(isDark);
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return CupertinoIcons.check_mark_circled_solid;
      case NotificationType.warning:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case NotificationType.error:
        return CupertinoIcons.xmark_circle_fill;
      case NotificationType.info:
      default:
        return CupertinoIcons.info_circle_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeManager,
      builder: (context, _) {
        final isDark = widget.themeManager.isDarkMode;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: Text(
              'Notifiche',
              style: AppTextStyles.title(isDark),
            ),
            trailing: _notifications.isNotEmpty
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: _markAllAsRead,
                    child: Text(
                      'Segna tutte',
                      style: TextStyle(
                        color: AppColors.primary(isDark),
                        fontSize: 16,
                      ),
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.bell_slash,
                                size: 64,
                                color: AppColors.textSecondary(isDark),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nessuna notifica',
                                style: AppTextStyles.title(isDark),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Le tue notifiche appariranno qui',
                                style: AppTextStyles.bodySecondary(isDark),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.only(bottom: 100),
                              children: [
                                ..._notifications.map((notification) {
                                  return _buildNotificationItem(
                                    notification: notification,
                                    isDark: isDark,
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          if (_notifications.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface(isDark),
                                border: Border(
                                  top: BorderSide(
                                    color: AppColors.borderColor(isDark).withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: SafeArea(
                                top: false,
                                child: CupertinoButton(
                                  color: AppColors.surface(isDark),
                                  onPressed: _deleteAllNotifications,
                                  child: Text(
                                    'Elimina tutte',
                                    style: TextStyle(
                                      color: CupertinoColors.systemRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required AppNotification notification,
    required bool isDark,
  }) {
    final color = _getNotificationColor(notification.type, isDark);
    final icon = _getNotificationIcon(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.white,
        ),
      ),
      onDismissed: (_) => _deleteNotification(notification),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _markAsRead(notification),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? AppColors.background(isDark)
                : AppColors.surface(isDark).withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                color: AppColors.borderColor(isDark).withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icona
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              // Contenuto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: AppColors.text(isDark),
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary(isDark),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(isDark).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
