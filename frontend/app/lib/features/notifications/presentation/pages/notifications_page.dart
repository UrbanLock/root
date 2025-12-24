import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/notifications/domain/models/app_notification.dart';
import 'package:app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:app/features/notifications/data/repositories/notification_repository.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/profile/domain/models/donation.dart';
import 'package:app/features/profile/presentation/pages/donation_detail_page.dart';

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
  final NotificationRepository _notificationRepository =
      AppDependencies.notificationRepository;
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _showAllReadBanner = false;

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

    if (mounted) {
      setState(() {
        _showAllReadBanner = true;
      });

      // Nasconde il banner dopo un breve intervallo
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showAllReadBanner = false;
          });
        }
      });
    }
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
            trailing: _buildNavBarActions(isDark),
          ),
          child: SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _notifications.isEmpty
                    ? CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          CupertinoSliverRefreshControl(
                            onRefresh: _loadNotifications,
                          ),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
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
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          if (_showAllReadBanner) _buildAllReadBanner(isDark),
                          Expanded(
                            child: CupertinoScrollbar(
                              child: CustomScrollView(
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                slivers: [
                                  CupertinoSliverRefreshControl(
                                    onRefresh: _loadNotifications,
                                  ),
                                  SliverPadding(
                                    padding:
                                        const EdgeInsets.only(bottom: 100),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final notification =
                                              _notifications[index];
                                          return _buildNotificationItem(
                                            notification: notification,
                                            isDark: isDark,
                                          );
                                        },
                                        childCount: _notifications.length,
                                      ),
                                    ),
                                  ),
                                ],
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

  /// Azioni nella navigation bar: "Segna tutte" + cestino
  Widget? _buildNavBarActions(bool isDark) {
    if (_notifications.isEmpty) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: _notifications.isNotEmpty ? _deleteAllNotifications : null,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.trash,
              size: 16,
              color: CupertinoColors.systemRed,
            ),
          ),
        ),
      ],
    );
  }

  /// Banner compatto che conferma che tutte le notifiche sono state segnate come lette.
  Widget _buildAllReadBanner(bool isDark) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _showAllReadBanner ? 1.0 : 0.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CupertinoColors.systemGreen.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 18,
                color: CupertinoColors.systemGreen,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Tutte le notifiche sono state segnate come lette',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.text(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        onPressed: () => _handleNotificationTap(notification),
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

  Future<void> _handleNotificationTap(AppNotification notification) async {
    // Segna come letta
    await _markAsRead(notification);

    // Se non c'è payload strutturato, non c'è nulla da aprire
    if (notification.payload == null) return;

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(notification.payload!) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    // Donazioni: il backend inserisce donazioneId nello pseudo-payload
    final donationId = payload['donazioneId'] as String?;
    if (donationId == null || donationId.isEmpty) {
      return;
    }

    try {
      final repo = AppDependencies.donationRepository;
      final Donation donation = await repo.getDonationById(donationId);
      if (!mounted) return;

      final category = donation.category ?? 'Altro';

      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => DonationDetailPage(
            themeManager: widget.themeManager,
            donation: {
              'id': donation.id,
              'itemName': donation.itemName,
              'category': category,
              'description': donation.description,
              'date': donation.createdAt,
              'status': donation.status,
              'hasPhoto': donation.photoUrl != null,
              'rejectionReason': donation.rejectionReason,
              'lockerId': donation.lockerId,
              'lockerName': donation.lockerName,
              'cellId': donation.cellId,
              'pickupAtComune': donation.pickupAtComune,
              'scheduledPickup': donation.scheduledPickup,
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Errore'),
          content: Text(
            'Impossibile aprire i dettagli della donazione.\n$e',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
}
