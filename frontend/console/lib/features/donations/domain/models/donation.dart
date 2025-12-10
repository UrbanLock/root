enum DonationStatus {
  daVisionare('Da visionare', 'da_visionare'),
  inValutazione('In valutazione', 'in_valutazione'),
  accettata('Accettata', 'accettata'),
  rifiutata('Rifiutata', 'rifiutata');

  final String label;
  final String value;

  const DonationStatus(this.label, this.value);

  DonationStatus get nextStatus {
    switch (this) {
      case DonationStatus.daVisionare:
        return DonationStatus.inValutazione;
      case DonationStatus.inValutazione:
        return DonationStatus.inValutazione; // Da qui si può accettare o rifiutare
      case DonationStatus.accettata:
      case DonationStatus.rifiutata:
        return this; // Stati finali
    }
  }
}

enum DonationCategory {
  sportivi('Sportivi'),
  personali('Personali'),
  petFriendly('Pet-Friendly'),
  commerciali('Commerciali'),
  cicloturistici('Cicloturistici');

  final String label;

  const DonationCategory(this.label);
}

class Donation {
  final String id;
  final String donorName;
  final String itemName;
  final String itemDescription;
  final DonationCategory category;
  final DateTime createdAt;
  final DonationStatus status;
  final String? photoUrl;
  final String? lockerId; // Se accettata e destinata a un locker
  final String? cellId; // Se accettata e destinata a una cella
  final bool isComunePickup; // Se il ritiro è al comune

  const Donation({
    required this.id,
    required this.donorName,
    required this.itemName,
    required this.itemDescription,
    required this.category,
    required this.createdAt,
    this.status = DonationStatus.daVisionare,
    this.photoUrl,
    this.lockerId,
    this.cellId,
    this.isComunePickup = false,
  });

  Donation copyWith({
    String? id,
    String? donorName,
    String? itemName,
    String? itemDescription,
    DonationCategory? category,
    DateTime? createdAt,
    DonationStatus? status,
    String? photoUrl,
    String? lockerId,
    String? cellId,
    bool? isComunePickup,
  }) {
    return Donation(
      id: id ?? this.id,
      donorName: donorName ?? this.donorName,
      itemName: itemName ?? this.itemName,
      itemDescription: itemDescription ?? this.itemDescription,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      lockerId: lockerId ?? this.lockerId,
      cellId: cellId ?? this.cellId,
      isComunePickup: isComunePickup ?? this.isComunePickup,
    );
  }
}

