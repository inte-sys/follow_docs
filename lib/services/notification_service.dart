import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      tz_data.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notifications.initialize(initializationSettings);

      // Solicitar permisos para Android 13+
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _configureLocalTimeZone().timeout(
        const Duration(seconds: 3),
        onTimeout: () => tz.setLocalLocation(tz.getLocation('UTC')),
      );
    } catch (e) {
      debugPrint("Error en init: $e");
    }
  }

  Future<void> _configureLocalTimeZone() async {
    final dynamic tzRaw = await FlutterTimezone.getLocalTimezone();
    String locationName;

    if (tzRaw is! String) {
      locationName = tzRaw.identifier;
    } else {
      locationName = tzRaw;
    }
    tz.setLocalLocation(tz.getLocation(locationName));
  }

  Future<void> scheduleExpirationNotice({
    required String id,
    required String title,
    required DateTime expiryDate,
  }) async {
    DateTime scheduleDate = expiryDate.subtract(const Duration(days: 30));

    if (scheduleDate.isBefore(DateTime.now())) {
      scheduleDate = DateTime.now().add(const Duration(seconds: 10));
    }

    try {
      await _notifications.zonedSchedule(
        id.hashCode,
        '¡Recordatorio de Vencimiento!',
        'Tu documento "$title" vence pronto.',
        tz.TZDateTime.from(scheduleDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'follow_docs_v2',
            'Alertas de Vencimiento',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("Notificación programada con éxito para: $scheduleDate");
    } catch (e) {
      debugPrint("Error al programar notificación: $e");
    }
  }

  Future<void> showInstantNotification(String title) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'follow_docs_v2',
      'Alertas de Prueba',
      channelDescription: 'Canal para validación del sistema',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
    );

    await _notifications.show(
      999,
      'Prueba de Notificación',
      'El sistema está activo para: $title',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelNotification(String id) async {
    await _notifications.cancel(id.hashCode);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // CORRECCIÓN: Eliminada la resta de 7 días para usar el cálculo exacto de la UI
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint("La fecha de notificación ya pasó: $scheduledDate");
      return;
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'follow_docs_v2', // Usamos el canal principal verificado
          'Vencimientos',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint("Notificación programada para: $scheduledDate");
  }
}
