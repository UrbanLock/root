import 'package:console/features/lockers/domain/models/locker_type.dart';

/// Dati di affluenza per una specifica ora del giorno
class HourlyAffluence {
  final int hour; // 0-23
  final int count; // Numero di utilizzi

  const HourlyAffluence({
    required this.hour,
    required this.count,
  });
}

/// Dati di affluenza per categoria
class CategoryAffluence {
  final LockerType category;
  final int count;

  const CategoryAffluence({
    required this.category,
    required this.count,
  });
}

/// Dati di affluenza per fascia oraria e categoria
class TimeSlotCategoryData {
  final String timeSlot; // Es: "08:00-12:00"
  final Map<LockerType, int> categoryCounts;

  const TimeSlotCategoryData({
    required this.timeSlot,
    required this.categoryCounts,
  });
}

/// Statistiche di utilizzo di una zona/area (generico per tutte le categorie)
class ZoneUsage {
  final String zoneId;
  final String zoneName;
  final int totalUsage;

  const ZoneUsage({
    required this.zoneId,
    required this.zoneName,
    required this.totalUsage,
  });
}

/// Statistiche di utilizzo di un locker
class LockerUsage {
  final String lockerId;
  final String lockerName;
  final String lockerCode;
  final int totalUsage;

  const LockerUsage({
    required this.lockerId,
    required this.lockerName,
    required this.lockerCode,
    required this.totalUsage,
  });
}

