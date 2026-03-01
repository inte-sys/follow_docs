// import 'package:flutter/material.dart';

enum ItemType { folder, document }

class FollowItem {
  final String id;
  final String name;
  final ItemType type;
  final DateTime? expirationDate;
  final bool isActive;

  FollowItem({
    required this.id,
    required this.name,
    required this.type,
    this.expirationDate,
    this.isActive = true,
  });

  // Regla [10, 11, 12]: Cálculo de la pista de vencimiento
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
      String prefix = (weeks - weeks.floor() > 0.5) ? "+" : "";
      return "$prefix${weeks.floor()} semanas";
    } else {
      double years = days.abs() / 365;
      String prefix = (years - years.floor() > 0.5) ? "+" : "";
      return "$prefix${years.floor()} años";
    }
  }

  bool get isExpired =>
      expirationDate != null && expirationDate!.isBefore(DateTime.now());
}
