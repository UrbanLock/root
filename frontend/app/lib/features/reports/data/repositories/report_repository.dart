import 'package:app/features/reports/domain/models/report.dart';

abstract class ReportRepository {
  Future<List<Report>> getReports();

  Future<Report> getReportById(String id);

  Future<Report> createReport({
    String? lockerId,
    String? cellId,
    required String category,
    required String description,
    String? base64Photo,
  });

  Future<Report> updateReport(
    String id, {
    String? category,
    String? description,
    String? base64Photo,
  });

  Future<void> deleteReport(String id);
}

import 'package:app/features/reports/domain/models/report.dart';

abstract class ReportRepository {
  Future<List<Report>> getReports({int page, int limit});

  Future<Report> createReport({
    String? lockerId,
    String? cellId,
    required String category,
    required String description,
    String? base64Photo,
  });

  Future<Report> updateReport({
    required String id,
    String? category,
    String? description,
    String? base64Photo,
  });

  Future<void> deleteReport(String id);
}


