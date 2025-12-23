import 'package:console/features/analytics/domain/models/analytics_data.dart';
import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/features/lockers/data/mock_lockers.dart';

/// Mock data per le affluenze orarie (0-23)
final List<HourlyAffluence> mockHourlyAffluence = [
  const HourlyAffluence(hour: 0, count: 5),
  const HourlyAffluence(hour: 1, count: 3),
  const HourlyAffluence(hour: 2, count: 2),
  const HourlyAffluence(hour: 3, count: 1),
  const HourlyAffluence(hour: 4, count: 2),
  const HourlyAffluence(hour: 5, count: 8),
  const HourlyAffluence(hour: 6, count: 15),
  const HourlyAffluence(hour: 7, count: 45),
  const HourlyAffluence(hour: 8, count: 78),
  const HourlyAffluence(hour: 9, count: 92),
  const HourlyAffluence(hour: 10, count: 85),
  const HourlyAffluence(hour: 11, count: 95),
  const HourlyAffluence(hour: 12, count: 120),
  const HourlyAffluence(hour: 13, count: 110),
  const HourlyAffluence(hour: 14, count: 105),
  const HourlyAffluence(hour: 15, count: 98),
  const HourlyAffluence(hour: 16, count: 112),
  const HourlyAffluence(hour: 17, count: 125),
  const HourlyAffluence(hour: 18, count: 95),
  const HourlyAffluence(hour: 19, count: 68),
  const HourlyAffluence(hour: 20, count: 45),
  const HourlyAffluence(hour: 21, count: 32),
  const HourlyAffluence(hour: 22, count: 18),
  const HourlyAffluence(hour: 23, count: 10),
];

/// Mock data per affluenze per categoria
final List<CategoryAffluence> mockCategoryAffluence = [
  const CategoryAffluence(category: LockerType.sportivi, count: 450),
  const CategoryAffluence(category: LockerType.personali, count: 320),
  const CategoryAffluence(category: LockerType.petFriendly, count: 180),
  const CategoryAffluence(category: LockerType.commerciali, count: 250),
  const CategoryAffluence(category: LockerType.cicloturistici, count: 210),
];

/// Mock data per fasce orarie con statistiche per categoria
final List<TimeSlotCategoryData> mockTimeSlotCategoryData = [
  TimeSlotCategoryData(
    timeSlot: '00:00-06:00',
    categoryCounts: {
      LockerType.sportivi: 15,
      LockerType.personali: 8,
      LockerType.petFriendly: 5,
      LockerType.commerciali: 2,
      LockerType.cicloturistici: 3,
    },
  ),
  TimeSlotCategoryData(
    timeSlot: '06:00-12:00',
    categoryCounts: {
      LockerType.sportivi: 180,
      LockerType.personali: 95,
      LockerType.petFriendly: 45,
      LockerType.commerciali: 120,
      LockerType.cicloturistici: 85,
    },
  ),
  TimeSlotCategoryData(
    timeSlot: '12:00-18:00',
    categoryCounts: {
      LockerType.sportivi: 200,
      LockerType.personali: 150,
      LockerType.petFriendly: 90,
      LockerType.commerciali: 100,
      LockerType.cicloturistici: 95,
    },
  ),
  TimeSlotCategoryData(
    timeSlot: '18:00-24:00',
    categoryCounts: {
      LockerType.sportivi: 55,
      LockerType.personali: 67,
      LockerType.petFriendly: 40,
      LockerType.commerciali: 28,
      LockerType.cicloturistici: 27,
    },
  ),
];

/// Mock data per zone/aree per categoria
Map<LockerType, List<ZoneUsage>> mockZoneUsageByCategory = {
  LockerType.sportivi: [
    const ZoneUsage(zoneId: 'sport_zone1', zoneName: 'Parco Centrale', totalUsage: 1250),
    const ZoneUsage(zoneId: 'sport_zone2', zoneName: 'Parco Nord', totalUsage: 980),
    const ZoneUsage(zoneId: 'sport_zone3', zoneName: 'Parco Sud', totalUsage: 750),
    const ZoneUsage(zoneId: 'sport_zone4', zoneName: 'Parco Est', totalUsage: 620),
    const ZoneUsage(zoneId: 'sport_zone5', zoneName: 'Parco Ovest', totalUsage: 450),
  ],
  LockerType.personali: [
    const ZoneUsage(zoneId: 'pers_zone1', zoneName: 'Zona Centro', totalUsage: 1100),
    const ZoneUsage(zoneId: 'pers_zone2', zoneName: 'Zona Nord', totalUsage: 850),
    const ZoneUsage(zoneId: 'pers_zone3', zoneName: 'Zona Sud', totalUsage: 720),
    const ZoneUsage(zoneId: 'pers_zone4', zoneName: 'Zona Est', totalUsage: 530),
  ],
  LockerType.petFriendly: [
    const ZoneUsage(zoneId: 'pet_zone1', zoneName: 'Area Cani Centrale', totalUsage: 650),
    const ZoneUsage(zoneId: 'pet_zone2', zoneName: 'Area Cani Nord', totalUsage: 480),
    const ZoneUsage(zoneId: 'pet_zone3', zoneName: 'Area Cani Sud', totalUsage: 420),
  ],
  LockerType.commerciali: [
    const ZoneUsage(zoneId: 'comm_zone1', zoneName: 'Centro Commerciale 1', totalUsage: 950),
    const ZoneUsage(zoneId: 'comm_zone2', zoneName: 'Centro Commerciale 2', totalUsage: 780),
    const ZoneUsage(zoneId: 'comm_zone3', zoneName: 'Centro Commerciale 3', totalUsage: 520),
  ],
  LockerType.cicloturistici: [
    const ZoneUsage(zoneId: 'bike_zone1', zoneName: 'Pista Ciclabile Nord', totalUsage: 820),
    const ZoneUsage(zoneId: 'bike_zone2', zoneName: 'Pista Ciclabile Sud', totalUsage: 650),
    const ZoneUsage(zoneId: 'bike_zone3', zoneName: 'Pista Ciclabile Est', totalUsage: 480),
  ],
};

/// Mock data per locker usage per zona
Map<String, List<LockerUsage>> mockLockerUsageByZone = {
  // Sportivi
  'sport_zone1': [
    const LockerUsage(lockerId: 'locker1', lockerName: 'Locker Sportivo 1', lockerCode: 'SP001', totalUsage: 450),
    const LockerUsage(lockerId: 'locker2', lockerName: 'Locker Sportivo 2', lockerCode: 'SP002', totalUsage: 380),
    const LockerUsage(lockerId: 'locker3', lockerName: 'Locker Sportivo 3', lockerCode: 'SP003', totalUsage: 420),
  ],
  'sport_zone2': [
    const LockerUsage(lockerId: 'locker4', lockerName: 'Locker Sportivo 4', lockerCode: 'SP004', totalUsage: 320),
    const LockerUsage(lockerId: 'locker5', lockerName: 'Locker Sportivo 5', lockerCode: 'SP005', totalUsage: 280),
    const LockerUsage(lockerId: 'locker6', lockerName: 'Locker Sportivo 6', lockerCode: 'SP006', totalUsage: 380),
  ],
  'sport_zone3': [
    const LockerUsage(lockerId: 'locker7', lockerName: 'Locker Sportivo 7', lockerCode: 'SP007', totalUsage: 250),
    const LockerUsage(lockerId: 'locker8', lockerName: 'Locker Sportivo 8', lockerCode: 'SP008', totalUsage: 300),
    const LockerUsage(lockerId: 'locker9', lockerName: 'Locker Sportivo 9', lockerCode: 'SP009', totalUsage: 200),
  ],
  'sport_zone4': [
    const LockerUsage(lockerId: 'locker10', lockerName: 'Locker Sportivo 10', lockerCode: 'SP010', totalUsage: 220),
    const LockerUsage(lockerId: 'locker11', lockerName: 'Locker Sportivo 11', lockerCode: 'SP011', totalUsage: 200),
    const LockerUsage(lockerId: 'locker12', lockerName: 'Locker Sportivo 12', lockerCode: 'SP012', totalUsage: 200),
  ],
  'sport_zone5': [
    const LockerUsage(lockerId: 'locker13', lockerName: 'Locker Sportivo 13', lockerCode: 'SP013', totalUsage: 150),
    const LockerUsage(lockerId: 'locker14', lockerName: 'Locker Sportivo 14', lockerCode: 'SP014', totalUsage: 180),
    const LockerUsage(lockerId: 'locker15', lockerName: 'Locker Sportivo 15', lockerCode: 'SP015', totalUsage: 120),
  ],
  // Personali
  'pers_zone1': [
    const LockerUsage(lockerId: 'locker16', lockerName: 'Locker Personale 1', lockerCode: 'PE001', totalUsage: 380),
    const LockerUsage(lockerId: 'locker17', lockerName: 'Locker Personale 2', lockerCode: 'PE002', totalUsage: 360),
    const LockerUsage(lockerId: 'locker18', lockerName: 'Locker Personale 3', lockerCode: 'PE003', totalUsage: 360),
  ],
  'pers_zone2': [
    const LockerUsage(lockerId: 'locker19', lockerName: 'Locker Personale 4', lockerCode: 'PE004', totalUsage: 280),
    const LockerUsage(lockerId: 'locker20', lockerName: 'Locker Personale 5', lockerCode: 'PE005', totalUsage: 290),
    const LockerUsage(lockerId: 'locker21', lockerName: 'Locker Personale 6', lockerCode: 'PE006', totalUsage: 280),
  ],
  'pers_zone3': [
    const LockerUsage(lockerId: 'locker22', lockerName: 'Locker Personale 7', lockerCode: 'PE007', totalUsage: 240),
    const LockerUsage(lockerId: 'locker23', lockerName: 'Locker Personale 8', lockerCode: 'PE008', totalUsage: 240),
    const LockerUsage(lockerId: 'locker24', lockerName: 'Locker Personale 9', lockerCode: 'PE009', totalUsage: 240),
  ],
  'pers_zone4': [
    const LockerUsage(lockerId: 'locker25', lockerName: 'Locker Personale 10', lockerCode: 'PE010', totalUsage: 180),
    const LockerUsage(lockerId: 'locker26', lockerName: 'Locker Personale 11', lockerCode: 'PE011', totalUsage: 170),
    const LockerUsage(lockerId: 'locker27', lockerName: 'Locker Personale 12', lockerCode: 'PE012', totalUsage: 180),
  ],
  // Pet Friendly
  'pet_zone1': [
    const LockerUsage(lockerId: 'locker28', lockerName: 'Locker Pet 1', lockerCode: 'PF001', totalUsage: 220),
    const LockerUsage(lockerId: 'locker29', lockerName: 'Locker Pet 2', lockerCode: 'PF002', totalUsage: 210),
    const LockerUsage(lockerId: 'locker30', lockerName: 'Locker Pet 3', lockerCode: 'PF003', totalUsage: 220),
  ],
  'pet_zone2': [
    const LockerUsage(lockerId: 'locker31', lockerName: 'Locker Pet 4', lockerCode: 'PF004', totalUsage: 160),
    const LockerUsage(lockerId: 'locker32', lockerName: 'Locker Pet 5', lockerCode: 'PF005', totalUsage: 160),
    const LockerUsage(lockerId: 'locker33', lockerName: 'Locker Pet 6', lockerCode: 'PF006', totalUsage: 160),
  ],
  'pet_zone3': [
    const LockerUsage(lockerId: 'locker34', lockerName: 'Locker Pet 7', lockerCode: 'PF007', totalUsage: 140),
    const LockerUsage(lockerId: 'locker35', lockerName: 'Locker Pet 8', lockerCode: 'PF008', totalUsage: 140),
    const LockerUsage(lockerId: 'locker36', lockerName: 'Locker Pet 9', lockerCode: 'PF009', totalUsage: 140),
  ],
  // Commerciali
  'comm_zone1': [
    const LockerUsage(lockerId: 'locker37', lockerName: 'Locker Commerciale 1', lockerCode: 'CO001', totalUsage: 320),
    const LockerUsage(lockerId: 'locker38', lockerName: 'Locker Commerciale 2', lockerCode: 'CO002', totalUsage: 310),
    const LockerUsage(lockerId: 'locker39', lockerName: 'Locker Commerciale 3', lockerCode: 'CO003', totalUsage: 320),
  ],
  'comm_zone2': [
    const LockerUsage(lockerId: 'locker40', lockerName: 'Locker Commerciale 4', lockerCode: 'CO004', totalUsage: 260),
    const LockerUsage(lockerId: 'locker41', lockerName: 'Locker Commerciale 5', lockerCode: 'CO005', totalUsage: 260),
    const LockerUsage(lockerId: 'locker42', lockerName: 'Locker Commerciale 6', lockerCode: 'CO006', totalUsage: 260),
  ],
  'comm_zone3': [
    const LockerUsage(lockerId: 'locker43', lockerName: 'Locker Commerciale 7', lockerCode: 'CO007', totalUsage: 180),
    const LockerUsage(lockerId: 'locker44', lockerName: 'Locker Commerciale 8', lockerCode: 'CO008', totalUsage: 170),
    const LockerUsage(lockerId: 'locker45', lockerName: 'Locker Commerciale 9', lockerCode: 'CO009', totalUsage: 170),
  ],
  // Cicloturistici
  'bike_zone1': [
    const LockerUsage(lockerId: 'locker46', lockerName: 'Locker Bici 1', lockerCode: 'BI001', totalUsage: 280),
    const LockerUsage(lockerId: 'locker47', lockerName: 'Locker Bici 2', lockerCode: 'BI002', totalUsage: 270),
    const LockerUsage(lockerId: 'locker48', lockerName: 'Locker Bici 3', lockerCode: 'BI003', totalUsage: 270),
  ],
  'bike_zone2': [
    const LockerUsage(lockerId: 'locker49', lockerName: 'Locker Bici 4', lockerCode: 'BI004', totalUsage: 220),
    const LockerUsage(lockerId: 'locker50', lockerName: 'Locker Bici 5', lockerCode: 'BI005', totalUsage: 215),
    const LockerUsage(lockerId: 'locker51', lockerName: 'Locker Bici 6', lockerCode: 'BI006', totalUsage: 215),
  ],
  'bike_zone3': [
    const LockerUsage(lockerId: 'locker52', lockerName: 'Locker Bici 7', lockerCode: 'BI007', totalUsage: 160),
    const LockerUsage(lockerId: 'locker53', lockerName: 'Locker Bici 8', lockerCode: 'BI008', totalUsage: 160),
    const LockerUsage(lockerId: 'locker54', lockerName: 'Locker Bici 9', lockerCode: 'BI009', totalUsage: 160),
  ],
};

