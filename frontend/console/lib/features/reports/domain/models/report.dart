enum ReportStatus {
  inSospeso('In sospeso', 'in_sospeso'),
  visionata('Visionata', 'visionata'),
  inManutenzione('In manutenzione', 'in_manutenzione'),
  conclusa('Conclusa', 'conclusa');

  final String label;
  final String value;

  const ReportStatus(this.label, this.value);

  ReportStatus get nextStatus {
    switch (this) {
      case ReportStatus.inSospeso:
        return ReportStatus.visionata;
      case ReportStatus.visionata:
        return ReportStatus.inManutenzione;
      case ReportStatus.inManutenzione:
        return ReportStatus.conclusa;
      case ReportStatus.conclusa:
        return ReportStatus.conclusa; // Non può andare oltre
    }
  }
}

class StatusChangeHistory {
  final String operatorName;
  final DateTime changedAt;
  final ReportStatus fromStatus;
  final ReportStatus toStatus;

  const StatusChangeHistory({
    required this.operatorName,
    required this.changedAt,
    required this.fromStatus,
    required this.toStatus,
  });
}

class Report {
  final String id;
  final String lockerId;
  final String? cellId;
  final String category;
  final String categoryLabel;
  final String description;
  final DateTime createdAt;
  final ReportStatus status;
  final String? photoUrl; // URL o path della foto
  final List<StatusChangeHistory> statusHistory; // Cronologia dei cambi di stato

  const Report({
    required this.id,
    required this.lockerId,
    this.cellId,
    required this.category,
    required this.categoryLabel,
    required this.description,
    required this.createdAt,
    this.status = ReportStatus.inSospeso,
    this.photoUrl,
    this.statusHistory = const [],
  });

  Report copyWith({
    String? id,
    String? lockerId,
    String? cellId,
    String? category,
    String? categoryLabel,
    String? description,
    DateTime? createdAt,
    ReportStatus? status,
    String? photoUrl,
    List<StatusChangeHistory>? statusHistory,
  }) {
    return Report(
      id: id ?? this.id,
      lockerId: lockerId ?? this.lockerId,
      cellId: cellId ?? this.cellId,
      category: category ?? this.category,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }
}

