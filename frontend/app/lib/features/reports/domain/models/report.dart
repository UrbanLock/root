class Report {
  final String id;
  final String category;
  final String description;
  final DateTime createdAt;
  final String? lockerId;
  final String? lockerName;
  final String? cellaId;
  final String status;
  final String? photoUrl;

  const Report({
    required this.id,
    required this.category,
    required this.description,
    required this.createdAt,
    required this.lockerId,
    required this.lockerName,
    required this.cellaId,
    required this.status,
    required this.photoUrl,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      category: (json['category'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lockerId: json['lockerId'] as String?,
      lockerName: json['lockerName'] as String?,
      cellaId: json['cellaId'] as String?,
      status: (json['status'] ?? '') as String,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Color statusColor(bool isDark) {
    // Definito esternamente in UI; qui lasciamo un placeholder se necessario
    return const Color(0xFF000000);
  }

  String get statusLabel {
    switch (status) {
      case 'aperta':
        return 'Aperta';
      case 'in_lavorazione':
        return 'In lavorazione';
      case 'risolta':
        return 'Risolta';
      case 'chiusa':
        return 'Chiusa';
      default:
        return 'Sconosciuto';
    }
  }
}

class Report {
  final String id;
  final String category;
  final String description;
  final String? photoUrl;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? operatorResponse;
  final String? lockerId;
  final String? lockerName;
  final String? cellId;

  const Report({
    required this.id,
    required this.category,
    required this.description,
    required this.photoUrl,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
    required this.operatorResponse,
    required this.lockerId,
    required this.lockerName,
    required this.cellId,
  });

  /// Crea un Report a partire dal JSON del backend
  ///
  /// Backend (`formatReportResponse`) restituisce:
  /// {
  ///   id, category, description, photoUrl, priority, status,
  ///   createdAt, resolvedAt, operatorResponse,
  ///   lockerId, lockerName, lockerType, lockerPosition,
  ///   cellaId, assignedOperatorId, assignedOperatorName
  /// }
  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      category: (json['category'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      photoUrl: json['photoUrl'] as String?,
      priority: (json['priority'] ?? 'media') as String,
      status: (json['status'] ?? 'aperta') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      operatorResponse: json['operatorResponse'] as String?,
      lockerId: json['lockerId'] as String?,
      lockerName: json['lockerName'] as String?,
      cellId: json['cellaId'] as String?,
    );
  }
}


