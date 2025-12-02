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

  /// Notifica quando una cella è aperta e l'app va in background
  /// 
  /// **Caso d'uso**: L'utente ha aperto una cella ma chiude l'app prima di chiudere lo sportello
  Future<void> notifyOpenCellInBackground(ActiveCell cell) async {
    // Genera un ID valido (32-bit integer) usando hash della stringa
    // Questo evita errori quando cell.id è troppo grande (es. timestamp)
    final cellIdHash = cell.id.hashCode.abs() % 1000000; // Limita a 6 cifre
    
    await showNotification(
      id: 1000 + cellIdHash, // ID univoco per ogni cella (valido per 32-bit)
      title: 'Cella aperta',
      body: 'Ricorda di chiudere lo sportello della ${cell.cellNumber} al locker ${cell.lockerName}',
      payload: 'open_cell_${cell.id}',
    );

    // Programma un promemoria dopo 5 minuti se la cella è ancora aperta
    await scheduleNotification(
      id: 2000 + cellIdHash,
      title: 'Promemoria: Cella aperta',
      body: 'La ${cell.cellNumber} al locker ${cell.lockerName} è ancora aperta. Ricorda di chiudere lo sportello.',
      scheduledDate: DateTime.now().add(const Duration(minutes: 5)),
      payload: 'reminder_cell_${cell.id}',
    );
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

  /// Notifica quando lo sportello è stato chiuso con successo
  /// 
  /// **Caso d'uso**: Conferma all'utente che l'operazione è completata
  Future<void> notifyCellClosed(ActiveCell cell) async {
    final cellIdHash = cell.id.hashCode.abs() % 1000000;
    await showNotification(
      id: 5000 + cellIdHash,
      title: 'Cella chiusa',
      body: 'La ${cell.cellNumber} al locker ${cell.lockerName} è stata chiusa con successo',
      payload: 'closed_cell_${cell.id}',
    );

    // Cancella i promemoria programmati per questa cella
    await cancelNotification(1000 + cellIdHash);
    await cancelNotification(2000 + cellIdHash);
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

