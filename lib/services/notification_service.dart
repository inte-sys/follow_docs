import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
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
    // Regla de Negocio: 1 mes antes
    final scheduleDate = expiryDate.subtract(const Duration(days: 30));

    // Si la fecha ya pasó, no programamos nada
    if (scheduleDate.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      id.hashCode,
      '¡Documento por vencer!',
      'Tu $title vencerá en 30 días.',
      tz.TZDateTime.from(scheduleDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'follow_docs_id', 'Vencimientos',
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