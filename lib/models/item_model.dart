// // import 'package:flutter/material.dart';

// enum ItemType { folder, document }

// class FollowItem {
//   final String id;
//   final String name;
//   final ItemType type;
//   final DateTime? expirationDate;
//   final bool isActive;

//   FollowItem({
//     required this.id,
//     required this.name,
//     required this.type,
//     this.expirationDate,
//     this.isActive = true,
//   });

//   // Regla [10, 11, 12]: Cálculo de la pista de vencimiento
//   String get expirationHint {
//     if (expirationDate == null) return "";
//     final now = DateTime.now();
//     final difference = expirationDate!.difference(now);
//     final days = difference.inDays;

//     if (days == 0) return "Hoy";
//     if (days == 1) return "Mañana";
//     if (days == -1) return "Ayer";

//     if (days.abs() < 30) {
//       return "${days.abs()} días";
//     } else if (days.abs() < 365) {
//       double weeks = days.abs() / 7;
//       String prefix = (weeks - weeks.floor() > 0.5) ? "+" : "";
//       return "$prefix${weeks.floor()} semanas";
//     } else {
//       double years = days.abs() / 365;
//       String prefix = (years - years.floor() > 0.5) ? "+" : "";
//       return "$prefix${years.floor()} años";
//     }
//   }

//   bool get isExpired =>
//       expirationDate != null && expirationDate!.isBefore(DateTime.now());
// }

enum ItemType { folder, document }

class FollowItem {
  final String id;
  final String name;
  final ItemType type;
  final DateTime? expirationDate;
  final bool isActive;
  // Nuevos campos para la configuración de alertas
  final int notifValue;
  final String notifUnit;

  FollowItem({
    required this.id,
    required this.name,
    required this.type,
    this.expirationDate,
    this.isActive = true,
    this.notifValue = 7,
    this.notifUnit = 'Días',
  });

  // Convierte un registro de la base de datos (Map) a un objeto FollowItem
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
      notifValue: map['notif_value'] ?? 7,
      notifUnit: map['notif_unit'] ?? 'Días',
    );
  }

  // Convierte este objeto a un Map para guardarlo en la base de datos
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

  // Cálculo de la pista de vencimiento (Regla 10, 11, 12)
  String get expirationHint {
    if (expirationDate == null) return "";
    final now = DateTime.now();
    final difference = expirationDate!.difference(now);
    final days = difference.inDays;

    if (days == 0) return "Hoy";
    if (days == 1) return "Mañana";
    if (days == -1) return "Ayer";

    if (days.abs() < 30) {
      return "${days.abs()} días";
    } else if (days.abs() < 365) {
      double weeks = days.abs() / 7;
      return "${weeks.floor()} semanas";
    } else {
      double years = days.abs() / 365;
      return "${years.floor()} años";
    }
  }

  bool get isExpired =>
      expirationDate != null && expirationDate!.isBefore(DateTime.now());
}
