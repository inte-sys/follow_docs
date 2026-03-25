enum ReminderType { notification, email, calendar } // [cite: 27]

class ReminderConfig {
  ReminderType type;
  int value;
  String unit; // días, semanas, meses, años

  // Configuración predeterminada: Notificación 1 mes antes
  ReminderConfig({
    this.type = ReminderType.notification,
    this.value = 1,
    this.unit = "meses",
  });
}
