import 'package:app/features/profile/domain/models/donation.dart';

abstract class DonationRepository {
  Future<List<Donation>> getDonations({int page, int limit});

  Future<Donation> getDonationById(String id);

  Future<Donation> createDonation({
    required String itemName,
    required String equipmentType,
    String? category,
    required String description,
    String? base64Photo,
  });

  Future<Donation> updateDonation({
    required String id,
    String? itemName,
    String? equipmentType,
    String? category,
    String? description,
    String? base64Photo,
  });

  Future<void> deleteDonation(String id);

  /// Concorda data/ora di ritiro con l'operatore
  Future<Donation> schedulePickup({
    required String id,
    required DateTime pickupDate,
    String? note,
  });
}


