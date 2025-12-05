import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/notifications/domain/models/app_notification.dart';
import 'package:app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:app/features/notifications/data/repositories/notification_repository.dart';

/// Servizio per gestire le notifiche locali e di sistema
/// 
/// **TODO quando il backend sarà pronto:**
/// - Aggiungere notifiche push dal backend
/// - Sincronizzare notifiche con il server
/// - Gestire notifiche in tempo reale tramite WebSocket
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final NotificationRepository _notificationRepository = NotificationRepositoryImpl();
  bool _initialized = false;

  /// Inizializza il servizio di notifiche
  /// 
  /// **IMPORTANTE**: Chiamare questo metodo all'avvio dell'app (in main.dart)
  Future<void> initialize() async {
    if (_initialized) return;

    // Inizializza timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));

    // Configurazione Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configurazione iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Richiedi permessi per Android 13+
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Callback quando una notifica viene toccata
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Navigare alla schermata appropriata in base al payload
    debugPrint('Notifica toccata: ${response.payload}');
  }

  /// Mostra una notifica immediata
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'null_app_channel',
      'NULL App Notifiche',
      channelDescription: 'Notifiche per l\'app NULL',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Programma una notifica per un momento specifico
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'null_app_channel',
      'NULL App Notifiche',
      channelDescription: 'Notifiche per l\'app NULL',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Programma promemoria per restituire un oggetto preso in prestito
  /// 
  /// **Caso d'uso**: Avvisa l'utente 1 giorno prima della scadenza che deve restituire l'oggetto
  Future<void> scheduleBorrowReturnReminder(ActiveCell cell) async {
    if (cell.endTime == null || cell.type != CellUsageType.borrowed) return;
    
    final cellIdHash = cell.id.hashCode.abs() % 1000000;
    final reminderDate = cell.endTime!.subtract(const Duration(days: 1));
    
    // Programma solo se la scadenza è almeno 1 giorno nel futuro
    if (reminderDate.isAfter(DateTime.now())) {
      final notificationId = 'borrow_reminder_${cell.id}';
      
      await scheduleNotification(
        id: 1000 + cellIdHash,
        title: 'Promemoria: Restituisci oggetto',
        body: 'Ricorda di restituire l\'oggetto nella ${cell.cellNumber} al locker ${cell.lockerName} entro domani',
        scheduledDate: reminderDate,
        payload: notificationId,
      );

      await _addAppNotification(
        id: notificationId,
        title: 'Promemoria programmato',
        body: 'Ti ricorderemo di restituire l\'oggetto nella ${cell.cellNumber} al locker ${cell.lockerName} il ${_formatDate(reminderDate)}',
        type: NotificationType.info,
        payload: notificationId,
      );
    }
  }

  /// Programma promemoria per ritirare un deposito
  /// 
  /// **Caso d'uso**: Avvisa l'utente 1 giorno prima della scadenza che deve ritirare il deposito
  Future<void> scheduleDepositPickupReminder(ActiveCell cell) async {
    if (cell.endTime == null || cell.type != CellUsageType.deposited) return;
    
    final cellIdHash = cell.id.hashCode.abs() % 1000000;
    final reminderDate = cell.endTime!.subtract(const Duration(days: 1));
    
    // Programma solo se la scadenza è almeno 1 giorno nel futuro
    if (reminderDate.isAfter(DateTime.now())) {
      final notificationId = 'deposit_reminder_${cell.id}';
      
      await scheduleNotification(
        id: 2000 + cellIdHash,
        title: 'Promemoria: Ritira deposito',
        body: 'Ricorda di ritirare il tuo deposito dalla ${cell.cellNumber} al locker ${cell.lockerName} entro domani',
        scheduledDate: reminderDate,
        payload: notificationId,
      );

      await _addAppNotification(
        id: notificationId,
        title: 'Promemoria programmato',
        body: 'Ti ricorderemo di ritirare il deposito dalla ${cell.cellNumber} al locker ${cell.lockerName} il ${_formatDate(reminderDate)}',
        type: NotificationType.info,
        payload: notificationId,
      );
    }
  }

  /// Formatta una data per la visualizzazione
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Notifica quando una cella sta per scadere
  /// 
  /// **Caso d'uso**: Avvisa l'utente che la cella scadrà presto
  Future<void> notifyCellExpiringSoon(ActiveCell cell) async {
    if (cell.endTime == null) return;

    final timeUntilExpiry = cell.endTime!.difference(DateTime.now());
    
    // Notifica solo se mancano meno di 1 ora
    if (timeUntilExpiry.inHours < 1 && timeUntilExpiry.inMinutes > 0) {
      final cellIdHash = cell.id.hashCode.abs() % 1000000;
      await showNotification(
        id: 3000 + cellIdHash,
        title: 'Cella in scadenza',
        body: 'La ${cell.cellNumber} al locker ${cell.lockerName} scade tra ${timeUntilExpiry.inMinutes} minuti',
        payload: 'expiring_cell_${cell.id}',
      );
    }
  }

  /// Notifica quando una cella è scaduta
  /// 
  /// **Caso d'uso**: Avvisa l'utente che deve ritirare/depositare l'oggetto
  Future<void> notifyCellExpired(ActiveCell cell) async {
    final cellIdHash = cell.id.hashCode.abs() % 1000000;
    await showNotification(
      id: 4000 + cellIdHash,
      title: 'Cella scaduta',
      body: 'La ${cell.cellNumber} al locker ${cell.lockerName} è scaduta. ${cell.type == CellUsageType.deposited ? "Ritira il tuo oggetto" : "Rimetti l\'oggetto"}',
      payload: 'expired_cell_${cell.id}',
    );
  }


  /// Aggiunge una notifica all'app (nella sezione notifiche)
  Future<void> _addAppNotification({
    required String id,
    required String title,
    required String body,
    required NotificationType type,
    String? payload,
  }) async {
    final notification = AppNotification(
      id: id,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      payload: payload,
    );
    await _notificationRepository.addNotification(notification);
  }


  /// Notifica quando lo stato di una donazione cambia
  Future<void> notifyDonationStatusChanged({
    required String donationId,
    required String itemName,
    required String status,
    String? rejectionReason,
  }) async {
    final notificationId = 'donation_${donationId}_${status}';
    final notificationIdHash = notificationId.hashCode.abs() % 1000000;
    
    String title;
    String body;
    NotificationType type;

    switch (status) {
      case 'confermata':
        title = 'Donazione confermata';
        body = 'La tua donazione "$itemName" è stata confermata. Puoi consegnarla al Comune di Trento.';
        type = NotificationType.success;
        break;
      case 'rifiutata':
        title = 'Donazione rifiutata';
        body = rejectionReason != null && rejectionReason.isNotEmpty
            ? 'La tua donazione "$itemName" è stata rifiutata: $rejectionReason'
            : 'La tua donazione "$itemName" è stata rifiutata.';
        type = NotificationType.error;
        break;
      case 'consegnata':
        title = 'Donazione consegnata';
        body = 'Grazie! La tua donazione "$itemName" è stata consegnata con successo.';
        type = NotificationType.success;
        break;
      default:
        title = 'Stato donazione aggiornato';
        body = 'Lo stato della tua donazione "$itemName" è stato aggiornato.';
        type = NotificationType.info;
    }

    await showNotification(
      id: 7000 + notificationIdHash,
      title: title,
      body: body,
      payload: notificationId,
    );

    await _addAppNotification(
      id: notificationId,
      title: title,
      body: body,
      type: type,
      payload: notificationId,
    );
  }

  /// Notifica quando un oggetto viene restituito
  Future<void> notifyItemReturned({
    required String cellNumber,
    required String lockerName,
    required String itemName,
  }) async {
    final notificationId = 'return_${DateTime.now().millisecondsSinceEpoch}';
    final notificationIdHash = notificationId.hashCode.abs() % 1000000;
    
    await showNotification(
      id: 8000 + notificationIdHash,
      title: 'Oggetto restituito',
      body: 'Hai restituito "$itemName" nella ${cellNumber} al locker ${lockerName}',
      payload: notificationId,
    );

    await _addAppNotification(
      id: notificationId,
      title: 'Oggetto restituito',
      body: 'Hai restituito "$itemName" nella ${cellNumber} al locker ${lockerName}',
      type: NotificationType.success,
      payload: notificationId,
    );
  }

  /// Notifica quando un prestito sta per scadere
  Future<void> notifyBorrowExpiringSoon({
    required String cellNumber,
    required String lockerName,
    required String itemName,
    required int daysRemaining,
  }) async {
    final notificationId = 'borrow_expiring_${DateTime.now().millisecondsSinceEpoch}';
    final notificationIdHash = notificationId.hashCode.abs() % 1000000;
    
    final title = 'Prestito in scadenza';
    final body = daysRemaining == 1
        ? 'Il prestito di "$itemName" scade domani. Ricorda di restituirlo nella ${cellNumber} al locker ${lockerName}'
        : 'Il prestito di "$itemName" scade tra $daysRemaining giorni. Ricorda di restituirlo nella ${cellNumber} al locker ${lockerName}';

    await showNotification(
      id: 9000 + notificationIdHash,
      title: title,
      body: body,
      payload: notificationId,
    );

    await _addAppNotification(
      id: notificationId,
      title: title,
      body: body,
      type: NotificationType.warning,
      payload: notificationId,
    );
  }

  /// Notifica quando un prestito è scaduto
  Future<void> notifyBorrowExpired({
    required String cellNumber,
    required String lockerName,
    required String itemName,
  }) async {
    final notificationId = 'borrow_expired_${DateTime.now().millisecondsSinceEpoch}';
    final notificationIdHash = notificationId.hashCode.abs() % 1000000;
    
    await showNotification(
      id: 10000 + notificationIdHash,
      title: 'Prestito scaduto',
      body: 'Il prestito di "$itemName" è scaduto. Restituisci l\'oggetto nella ${cellNumber} al locker ${lockerName}',
      payload: notificationId,
    );

    await _addAppNotification(
      id: notificationId,
      title: 'Prestito scaduto',
      body: 'Il prestito di "$itemName" è scaduto. Restituisci l\'oggetto nella ${cellNumber} al locker ${lockerName}',
      type: NotificationType.error,
      payload: notificationId,
    );
  }

  /// Notifica quando un ordine è pronto per il ritiro
  Future<void> notifyOrderReady({
    required String cellNumber,
    required String lockerName,
    required String orderNumber,
    required String storeName,
  }) async {
    final notificationId = 'order_ready_${orderNumber}';
    final notificationIdHash = notificationId.hashCode.abs() % 1000000;
    
    await showNotification(
      id: 11000 + notificationIdHash,
      title: 'Ordine pronto',
      body: 'Il tuo ordine #$orderNumber da $storeName è pronto. Ritiralo dalla ${cellNumber} al locker ${lockerName}',
      payload: notificationId,
    );

    await _addAppNotification(
      id: notificationId,
      title: 'Ordine pronto',
      body: 'Il tuo ordine #$orderNumber da $storeName è pronto. Ritiralo dalla ${cellNumber} al locker ${lockerName}',
      type: NotificationType.info,
      payload: notificationId,
    );
  }

  /// Notifica promemoria generico
  /// 
  /// **Caso d'uso**: Notifiche personalizzate per vari eventi
  Future<void> notifyReminder({
    required String title,
    required String body,
    DateTime? scheduledDate,
    String? payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch % 100000;

    if (scheduledDate != null) {
      await scheduleNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
      );
    } else {
      await showNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
    }
  }

  /// Cancella una notifica specifica
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancella tutte le notifiche
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Ottiene tutte le notifiche pendenti (solo Android)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}

