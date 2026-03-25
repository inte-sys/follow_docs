import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import '../views/home_screen.dart';

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

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Si el usuario toca el botón "Ver..." o la notificación misma
          if (response.payload != null) {
            HomeScreen.searchFromNotification(response.payload!);
          }
        },
      );

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
      debugPrint("Error en init de notificaciones: $e");
    }
  }

  Future<void> _configureLocalTimeZone() async {
    final dynamic tzRaw = await FlutterTimezone.getLocalTimezone();
    String locationName = tzRaw is! String ? tzRaw.identifier : tzRaw;
    tz.setLocalLocation(tz.getLocation(locationName));
  }

  /// Muestra una notificación inmediata (útil para pruebas)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Estilo de texto grande para que el mensaje no se corte
    final BigTextStyleInformation bigTextStyleInformation =
        BigTextStyleInformation(
      body,
      contentTitle: title,
      summaryText: 'Recordatorio de vencimiento',
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'follow_docs_v2',
      'Alertas de Documentos',
      channelDescription: 'Notificaciones sobre vencimientos de documentos',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: bigTextStyleInformation,
      fullScreenIntent: true,
      // Botón de acción solicitado
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'view_action',
          'Ver...',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    await _notifications.show(
      999,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  /// Cancela una notificación programada usando el ID del documento
  Future<void> cancelNotification(String id) async {
    await _notifications.cancel(id.hashCode);
  }

  /// Programa una notificación para una fecha y hora específica
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint("No se puede programar en el pasado: $scheduledDate");
      return;
    }

    final BigTextStyleInformation bigTextStyleInformation =
        BigTextStyleInformation(
      body,
      contentTitle: title,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'follow_docs_v2',
          'Vencimientos',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: bigTextStyleInformation,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload:
          title.split(':').last.trim(), // Enviamos el nombre para el filtro
    );
  }
}
