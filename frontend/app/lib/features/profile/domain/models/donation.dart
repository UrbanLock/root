class Donation {
  final String id;
  final String itemName;
  final String equipmentType;
  final String? category;
  final String description;
  final String? photoUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? scheduledPickup;
  final String? rejectionReason;
  final String? lockerId;
  final String? lockerName;
  final String? lockerType;

  const Donation({
    required this.id,
    required this.itemName,
    required this.equipmentType,
    required this.category,
    required this.description,
    required this.photoUrl,
    required this.status,
    required this.createdAt,
    required this.scheduledPickup,
    required this.rejectionReason,
    required this.lockerId,
    required this.lockerName,
    required this.lockerType,
  });

  /// Crea una Donation a partire dal JSON del backend
  ///
  /// Backend (`formatDonationResponse`) restituisce:
  /// {
  ///   id, nomeOggetto, tipoAttrezzatura, categoria, descrizione,
  ///   photoUrl, status, createdAt, scheduledPickup, rejectionReason,
  ///   lockerId, lockerName, lockerType, lockerPosition, assignedOperatorId, assignedOperatorName
  /// }
  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'] as String,
      itemName: (json['nomeOggetto'] ?? '') as String,
      equipmentType: (json['tipoAttrezzatura'] ?? '') as String,
      category: json['categoria'] as String?,
      description: (json['descrizione'] ?? '') as String,
      photoUrl: json['photoUrl'] as String?,
      status: (json['status'] ?? '') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      scheduledPickup: json['scheduledPickup'] != null
          ? DateTime.parse(json['scheduledPickup'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      lockerId: json['lockerId'] as String?,
      lockerName: json['lockerName'] as String?,
      lockerType: json['lockerType'] as String?,
    );
  }

  Map<String, dynamic> toJsonForCreate() {
    return {
      'nomeOggetto': itemName,
      'tipoAttrezzatura': equipmentType,
      'categoria': category,
      'descrizione': description,
      // La foto viene inviata separatamente come base64 dal form
    };
  }
}

class Donation {
  final String id;
  final String itemName;
  final String equipmentType;
  final String? category;
  final String description;
  final String? photoUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? scheduledPickup;
  final String? rejectionReason;
  final String? lockerId;
  final String? lockerName;
  final String? lockerType;

  const Donation({
    required this.id,
    required this.itemName,
    required this.equipmentType,
    required this.category,
    required this.description,
    required this.photoUrl,
    required this.status,
    required this.createdAt,
    required this.scheduledPickup,
    required this.rejectionReason,
    required this.lockerId,
    required this.lockerName,
    required this.lockerType,
  });

  /// Crea una Donation a partire dal JSON del backend
  ///
  /// Backend (`formatDonationResponse`) restituisce:
  /// {
  ///   id, nomeOggetto, tipoAttrezzatura, categoria, descrizione,
  ///   photoUrl, status, createdAt, scheduledPickup, rejectionReason,
  ///   lockerId, lockerName, lockerType, lockerPosition, assignedOperatorId, assignedOperatorName
  /// }
  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'] as String,
      itemName: (json['nomeOggetto'] ?? '') as String,
      equipmentType: (json['tipoAttrezzatura'] ?? '') as String,
      category: json['categoria'] as String?,
      description: (json['descrizione'] ?? '') as String,
      photoUrl: json['photoUrl'] as String?,
      status: (json['status'] ?? '') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      scheduledPickup: json['scheduledPickup'] != null
          ? DateTime.parse(json['scheduledPickup'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      lockerId: json['lockerId'] as String?,
      lockerName: json['lockerName'] as String?,
      lockerType: json['lockerType'] as String?,
    );
  }

  Map<String, dynamic> toJsonForCreate() {
    return {
      'nomeOggetto': itemName,
      'tipoAttrezzatura': equipmentType,
      'categoria': category,
      'descrizione': description,
      // La foto viene inviata separatamente come base64 dal form
    };
  }
}


