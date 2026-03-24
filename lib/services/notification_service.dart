import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
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
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notifications.initialize(initializationSettings);

      // Configuramos la zona horaria con un timeout de 3 segundos
      await _configureLocalTimeZone().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint("Timeout configurando zona horaria, usando fallback.");
          // Fallback manual inmediato si el sistema no responde
          tz.setLocalLocation(tz.getLocation('America/New_York'));
        },
      );
    } catch (e) {
      debugPrint("Error en initNotification: $e");
      // Aun con error, permitimos que la app continúe
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
    // 1. Calculamos la fecha ideal (30 días antes del vencimiento)
    DateTime scheduleDate = expiryDate.subtract(const Duration(days: 30));

    // 2. Lógica inteligente:
    // Si la fecha de aviso ya pasó o es hoy, avisamos en 10 segundos
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
            'follow_docs_v2', // El canal que ya verificamos que funciona
            'Alertas de Vencimiento',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, //
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime, //
      );
      debugPrint("Notificación programada con éxito para: $scheduleDate"); //
    } catch (e) {
      debugPrint("Error al programar notificación: $e"); //
    }
  }

  Future<void> showInstantNotification(String title) async {
    await _notifications.show(
      999,
      'Prueba Inmediata',
      'Si ves esto, el canal de $title funciona',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'follow_docs_v2',
          'Alertas',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> cancelNotification(String id) async {
    // Se usa la instancia de la clase, no la clase directamente
    await _notifications.cancel(id.hashCode);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Calculamos la fecha de la alerta (7 días antes del vencimiento)
    final notificationDate = scheduledDate.subtract(const Duration(days: 7));

    // Si la fecha de aviso ya pasó, no programamos nada
    if (notificationDate.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(notificationDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'vencimientos_channel',
          'Vencimientos',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
