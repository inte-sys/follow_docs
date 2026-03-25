enum ItemType { folder, document }

class FollowItem {
  final String id;
  final String name;
  final ItemType type;
  final DateTime? expirationDate;
  final bool isActive; // El elemento está activo en la lista
  final int notifValue; // 0 significa notificaciones APAGADAS
  final String notifUnit;

  FollowItem({
    required this.id,
    required this.name,
    required this.type,
    this.expirationDate,
    this.isActive = true,
    this.notifValue = 0,
    this.notifUnit = 'Días',
  });

  // Determina si las notificaciones están encendidas para este item
  bool get isNotifEnabled => notifValue > 0;

  factory FollowItem.fromMap(Map<String, dynamic> map) {
    return FollowItem(
      id: map['id'],
      name: map['name'],
      type: map['type'] == 'folder' ? ItemType.folder : ItemType.document,
      expirationDate: map['expiration_date'] != null &&
              map['expiration_date'] != ""
          ? DateTime.tryParse(
              map['expiration_date'].toString().split('/').reversed.join('-'))
          : null,
      isActive: map['is_active'] == 1,
      notifValue: map['notif_value'] ?? 0,
      notifUnit: map['notif_unit'] ?? 'Días',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == ItemType.folder ? 'folder' : 'document',
      'expiration_date': expirationDate != null
          ? "${expirationDate!.day.toString().padLeft(2, '0')}/${expirationDate!.month.toString().padLeft(2, '0')}/${expirationDate!.year}"
          : null,
      'is_active': isActive ? 1 : 0,
      'notif_value': notifValue,
      'notif_unit': notifUnit,
    };
  }

  String get expirationHint {
    if (expirationDate == null) return "";
    final now = DateTime.now();
    final difference = expirationDate!.difference(now);
    final days = difference.inDays;
    if (days == 0) return "Hoy";
    if (days == 1) return "Mañana";
    if (days == -1) return "Ayer";
    if (days.abs() < 30) return "${days.abs()} días";
    if (days.abs() < 365) return "${(days.abs() / 7).floor()} semanas";
    return "${(days.abs() / 365).floor()} años";
  }

  bool get isExpired =>
      expirationDate != null && expirationDate!.isBefore(DateTime.now());
}
