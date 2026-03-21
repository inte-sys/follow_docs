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
    tz.initializeTimeZones();
    // Edición 2 - Intento de corrección del error de cast en la zona horaria
    // try {
    //   // CORRECCIÓN: Usar explícitamente el método que devuelve el String
    //   final TimezoneInfo timeZoneName =
    //       await FlutterTimezone.getLocalTimezone();
    //   tz.setLocalLocation(tz.getLocation(timeZoneName as String));
    //   debugPrint("Zona horaria configurada correctamente: $timeZoneName");
    // } catch (e) {
    //   // Este es el error que estás viendo actualmente
    //   debugPrint("Error al configurar zona horaria: $e");
    //   // Opcional: Establecer una por defecto si falla (ej. Bogota/Lima/NY)
    //   // tz.setLocalLocation(tz.getLocation('America/Bogota'));
    // }

    // Edición 3 - Manejo robusto de la zona horaria para evitar el error de cast
    // Cambia la forma de obtener la zona horaria para evitar el error de cast
    //    try {
    //      // Usar .toString() asegura que siempre recibamos un String para tz.getLocation
    //      // final dynamic locationName = await FlutterTimezone.getLocalTimezone();
    //      // ignore: unnecessary_nullable_for_final_variable_declarations
    //      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    //      final String locationName =
    //          timezoneInfo.toString(); // Asegura que sea un String
    //      // if (locationName != null) {
    //      tz.setLocalLocation(tz.getLocation(locationName));
    //      // tz.setLocalLocation(tz.getLocation(locationName.toString()));
    //      // }
    //    } catch (e) {
    //      debugPrint("Fallo zona horaria: $e");
    //      tz.setLocalLocation(tz.getLocation('America/Bogota')); // Fallback seguro
    //    }

    // Edicion 4 - Manejo avanzado de la zona horaria con detección de formato y fallback inteligente
    try {
      final dynamic tzRaw = await FlutterTimezone.getLocalTimezone();
      String locationName;

      // Si devuelve el objeto TimezoneInfo (común en versiones 5.x)
      if (tzRaw is! String) {
        locationName =
            tzRaw.identifier; // Extrae solo el ID (ej: America/New_York)
      } else {
        locationName = tzRaw;
      }

      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (e) {
      debugPrint("Error crítico TZ: $e");
      // Fallback manual si el sistema sigue fallando
      tz.setLocalLocation(tz.getLocation('America/New_York'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings),
    );
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
    // El ID debe ser un entero para flutter_local_notifications.
    // Usamos el hashCode del String id como convención que ya manejamos.
    await FlutterLocalNotificationsPlugin.cancel(id.hashCode);
  }
}
