import 'package:latlong2/latlong.dart';
import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';

// Mock data per i lockers a Trento (posizioni di esempio - distribuite nel centro)
// Lockers specializzati: solo deposit, solo borrow, solo pickup, o misti (2-3 categorie)

final List<Locker> mockLockers = [
  // ============================================
  // LOCKER SOLO DEPOSITO (Personali)
  // ============================================
  Locker(
    id: 'pers-deposit-001',
    name: 'Centro Storico - Piazza Duomo',
    position: const LatLng(46.0700, 11.1200), // Centro esatto, Piazza Duomo
    type: LockerType.personali,
    totalCells: 25,
    availableCells: 18,
    description: 'Deposito effetti personali - Solo deposito',
  ),
  Locker(
    id: 'pers-deposit-002',
    name: 'Stazione FS',
    position: const LatLng(46.0750, 11.1250), // Nord-est, Stazione Ferroviaria
    type: LockerType.personali,
    totalCells: 35,
    availableCells: 26,
    description: 'Deposito bagagli e effetti personali - Solo deposito',
  ),

  // ============================================
  // LOCKER SOLO PRESTITO (Sportivi)
  // ============================================
  Locker(
    id: 'sport-borrow-001',
    name: 'Parco delle Albere',
    position: const LatLng(46.0820, 11.1320), // Nord-est, Parco delle Albere
    type: LockerType.sportivi,
    totalCells: 15,
    availableCells: 11,
    description: 'Attrezzature sportive e ricreative - Solo prestito',
  ),
  Locker(
    id: 'sport-borrow-002',
    name: 'Centro Sportivo',
    position: const LatLng(46.0720, 11.1150), // Centro-sud
    type: LockerType.sportivi,
    totalCells: 12,
    availableCells: 9,
    description: 'Prestito attrezzature sportive - Solo prestito',
  ),

  // ============================================
  // LOCKER SOLO PRESTITO (Pet-Friendly)
  // ============================================
  Locker(
    id: 'pet-borrow-001',
    name: 'Area Cani - Parco Fersina',
    position: const LatLng(46.0580, 11.1080), // Sud-ovest, Parco Fersina
    type: LockerType.petFriendly,
    totalCells: 10,
    availableCells: 7,
    description: 'Ciotole, giochi e sacchetti igienici - Solo prestito',
  ),

  // ============================================
  // LOCKER SOLO PRESTITO (Cicloturistici)
  // ============================================
  Locker(
    id: 'bike-borrow-001',
    name: 'Pista Ciclabile Adige',
    position: const LatLng(46.0650, 11.1280), // Est, lungo il fiume Adige
    type: LockerType.cicloturistici,
    totalCells: 8,
    availableCells: 6,
    description: 'Attrezzi manutenzione bici - Solo prestito',
  ),

  // ============================================
  // LOCKER SOLO RITIRO PRODOTTI (Commerciali)
  // ============================================
  Locker(
    id: 'comm-pickup-001',
    name: 'Via Manci - Centro Commerciale',
    position: const LatLng(46.0680, 11.1180), // Centro-ovest, Via Manci
    type: LockerType.commerciali,
    totalCells: 20,
    availableCells: 14,
    description: 'Ritiro prodotti locali - Solo ritiro',
  ),
  Locker(
    id: 'comm-pickup-002',
    name: 'Via Roma - Shopping',
    position: const LatLng(46.0710, 11.1220), // Centro, Via Roma
    type: LockerType.commerciali,
    totalCells: 18,
    availableCells: 12,
    description: 'Ritiro ordini negozi locali - Solo ritiro',
  ),

  // ============================================
  // LOCKER MISTI (2 categorie)
  // ============================================
  
  // Misto: Deposit + Borrow (Personali con prestito temporaneo)
  Locker(
    id: 'pers-mixed-001',
    name: 'Via Verdi - Zona Universitaria',
    position: const LatLng(46.0740, 11.1100), // Nord-ovest
    type: LockerType.personali,
    totalCells: 30,
    availableCells: 22,
    description: 'Deposito personale + prestito temporaneo',
  ),

  // Misto: Borrow + Deposit (Sportivi con deposito temporaneo)
  Locker(
    id: 'sport-mixed-001',
    name: 'Parco Gocciadoro',
    position: const LatLng(46.0800, 11.1200), // Nord
    type: LockerType.sportivi,
    totalCells: 20,
    availableCells: 15,
    description: 'Prestito attrezzature + deposito temporaneo',
  ),

  // Misto: Pickup + Deposit (Commerciali con deposito)
  Locker(
    id: 'comm-mixed-001',
    name: 'Via San Martino',
    position: const LatLng(46.0690, 11.1250), // Centro-est
    type: LockerType.commerciali,
    totalCells: 25,
    availableCells: 18,
    description: 'Ritiro prodotti + deposito temporaneo',
  ),

  // ============================================
  // LOCKER MISTI (3 categorie) - Rari
  // ============================================
  
  // Misto completo: Borrow + Deposit + Pickup (Hub centrale)
  Locker(
    id: 'hub-mixed-001',
    name: 'Piazza Fiera - Hub Centrale',
    position: const LatLng(46.0670, 11.1150), // Centro-sud
    type: LockerType.personali, // Tipo principale: personali
    totalCells: 40,
    availableCells: 30,
    description: 'Hub completo: prestito, deposito e ritiro prodotti',
  ),
];
