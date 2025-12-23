import 'package:console/features/donations/domain/models/donation.dart';

final List<Donation> mockDonations = [
  Donation(
    id: 'donation-001',
    donorName: 'Mario Rossi',
    itemName: 'Palla da calcio',
    itemDescription: 'Palla da calcio professionale in ottime condizioni',
    category: DonationCategory.sportivi,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    status: DonationStatus.daVisionare,
    photoUrl: 'https://via.placeholder.com/400x300?text=Palla+Calcio',
  ),
  Donation(
    id: 'donation-002',
    donorName: 'Luisa Bianchi',
    itemName: 'Borsa da viaggio',
    itemDescription: 'Borsa da viaggio grande, perfetta per depositi',
    category: DonationCategory.personali,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    status: DonationStatus.inValutazione,
    photoUrl: 'https://via.placeholder.com/400x300?text=Borsa+Viaggio',
  ),
  Donation(
    id: 'donation-003',
    donorName: 'Giovanni Verdi',
    itemName: 'Ciotola per cani',
    itemDescription: 'Ciotola portatile per cani, nuova',
    category: DonationCategory.petFriendly,
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    status: DonationStatus.inValutazione,
  ),
  Donation(
    id: 'donation-004',
    donorName: 'Anna Neri',
    itemName: 'Kit riparazione bici',
    itemDescription: 'Kit completo per riparazioni biciclette',
    category: DonationCategory.cicloturistici,
    createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    status: DonationStatus.accettata,
    lockerId: 'bike-borrow-001',
    cellId: 'bike-borrow-001_cell_3',
    isComunePickup: false,
  ),
  Donation(
    id: 'donation-005',
    donorName: 'Paolo Blu',
    itemName: 'Racchetta da tennis',
    itemDescription: 'Racchetta da tennis con corde nuove',
    category: DonationCategory.sportivi,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    status: DonationStatus.rifiutata,
  ),
  Donation(
    id: 'donation-006',
    donorName: 'Sara Gialli',
    itemName: 'Prodotti locali',
    itemDescription: 'Cesto di prodotti tipici trentini',
    category: DonationCategory.commerciali,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    status: DonationStatus.accettata,
    isComunePickup: true,
  ),
];



