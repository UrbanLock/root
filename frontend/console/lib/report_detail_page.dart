import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/features/reports/domain/models/report.dart';
import 'package:console/features/reports/data/mock_reports.dart';
import 'package:console/features/lockers/data/mock_lockers.dart';

class ReportDetailPage extends StatefulWidget {
  final Report report;
  final ThemeManager themeManager;
  
  const ReportDetailPage({
    super.key,
    required this.report,
    required this.themeManager,
  });

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Report _currentReport;

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
  }

  void _changeReportStatus() {
    // Se è già conclusa, non può cambiare stato
    if (_currentReport.status == ReportStatus.conclusa) {
      return;
    }

    final nextStatus = _currentReport.status.nextStatus;
    final operatorName = 'Operatore'; // TODO: Recuperare dal login
    
    setState(() {
      final updatedHistory = [
        ..._currentReport.statusHistory,
        StatusChangeHistory(
          operatorName: operatorName,
          changedAt: DateTime.now(),
          fromStatus: _currentReport.status,
          toStatus: nextStatus,
        ),
      ];
      
      _currentReport = _currentReport.copyWith(
        status: nextStatus,
        statusHistory: updatedHistory,
      );
      
      // Aggiorna anche nella lista mock (per persistenza)
      final index = mockReports.indexWhere((r) => r.id == _currentReport.id);
      if (index != -1) {
        mockReports[index] = _currentReport;
      }
    });
  }

  String _getLockerInfo() {
    final locker = mockLockers.firstWhere(
      (l) => l.id == _currentReport.lockerId,
      orElse: () => mockLockers.first,
    );
    
    if (_currentReport.cellId != null) {
      // Estrai il numero della cella dall'ID
      final parts = _currentReport.cellId!.split('_cell_');
      if (parts.length > 1) {
        final cellNumber = parts.last;
        return '${locker.name} (${locker.code}) - Cella $cellNumber';
      }
      return '${locker.name} (${locker.code}) - ${_currentReport.cellId}';
    }
    
    return '${locker.name} (${locker.code})';
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.inSospeso:
        return CupertinoColors.systemOrange;
      case ReportStatus.visionata:
        return CupertinoColors.systemBlue;
      case ReportStatus.inManutenzione:
        return CupertinoColors.systemYellow;
      case ReportStatus.conclusa:
        return CupertinoColors.systemGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.isDarkMode;
    final statusColor = _getStatusColor(_currentReport.status);
    
    return CupertinoPageScaffold(
      backgroundColor: isDark 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        middle: Text(
          'Segnalazione ${_currentReport.id.toUpperCase()}',
          style: TextStyle(
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
          ),
        ),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
          color: isDark ? CupertinoColors.white : CupertinoColors.black,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ID Segnalazione
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.doc_text,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID Segnalazione',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentReport.id.toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentReport.status.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (_currentReport.status != ReportStatus.conclusa) ...[
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: _changeReportStatus,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                CupertinoIcons.arrow_right_circle,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Locker e Cella
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.location,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentReport.cellId != null ? 'Locker e Cella' : 'Locker',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getLockerInfo(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Motivo di segnalazione
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.tag,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motivo di segnalazione',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentReport.categoryLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Descrizione
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.text_alignleft,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Descrizione',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark 
                                ? CupertinoColors.white 
                                : CupertinoColors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentReport.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark 
                            ? CupertinoColors.white 
                            : CupertinoColors.black,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Foto (se presente)
              if (_currentReport.photoUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? CupertinoColors.darkBackgroundGray 
                        : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.photo,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Foto',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentReport.photoUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: CupertinoColors.systemGrey.withOpacity(0.2),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.exclamationmark_triangle,
                                      color: CupertinoColors.systemGrey,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Impossibile caricare l\'immagine',
                                      style: TextStyle(
                                        color: CupertinoColors.systemGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: CupertinoColors.systemGrey.withOpacity(0.2),
                              child: Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Data di creazione
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data di creazione',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_currentReport.createdAt.day}/${_currentReport.createdAt.month}/${_currentReport.createdAt.year} ${_currentReport.createdAt.hour}:${_currentReport.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

