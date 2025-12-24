import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/reports/presentation/pages/report_issue_page.dart';
import 'package:app/features/reports/presentation/pages/report_detail_page.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/reports/domain/models/report.dart';

/// Pagina che mostra la lista delle segnalazioni inviate dall'utente
/// 
/// Mostra tutte le segnalazioni che l'utente ha inviato, con dettagli su:
/// - Categoria del problema
/// - Descrizione
/// - Data e ora
/// - Stato (in elaborazione, risolta, ecc.)
/// - Foto se presente
/// 
/// **TODO quando il backend sarà pronto:**
/// - Caricare segnalazioni dal backend (GET /api/v1/reports)
/// - Paginazione per grandi quantità di dati
/// - Filtri per stato e categoria
/// - Aggiornamento stato in tempo reale
class ReportsListPage extends StatefulWidget {
  final ThemeManager themeManager;

  const ReportsListPage({
    super.key,
    required this.themeManager,
  });

  @override
  State<ReportsListPage> createState() => _ReportsListPageState();
}

class _ReportsListPageState extends State<ReportsListPage> {
  List<Report> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reportRepository = AppDependencies.reportRepository;
      final fetchedReports = await reportRepository.getReports();
      if (!mounted) return;
      setState(() {
        _reports = fetchedReports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Errore nel caricamento delle segnalazioni: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Adesso';
        }
        return '${difference.inMinutes} minuti fa';
      }
      return '${difference.inHours} ore fa';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }


  void _createNewReport() async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ReportIssuePage(
          themeManager: widget.themeManager,
        ),
      ),
    );

    if (result == true) {
      await _loadReports();
    }
  }

  void _refreshReports() async {
    await _loadReports();
  }

  void _deleteReport(String reportId) {
    AppDependencies.reportRepository.deleteReport(reportId).then((_) {
      _loadReports();
    });
  }



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeManager,
      builder: (context, _) {
        final isDark = widget.themeManager.isDarkMode;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: Text(
              'Segnalazioni',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CupertinoActivityIndicator(radius: 20),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.exclamationmark_triangle,
                                size: 48,
                                color: AppColors.textSecondary(isDark),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: AppTextStyles.body(isDark),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              CupertinoButton.filled(
                                onPressed: _loadReports,
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _reports.isEmpty
                    ? Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.exclamationmark_triangle,
                                    size: 60,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nessuna segnalazione',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text(isDark),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Le tue segnalazioni appariranno qui',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textSecondary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Pulsante nuova segnalazione fisso in fondo
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _createNewReport,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    CupertinoIcons.add_circled_solid,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Nuova segnalazione',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // Lista scrollabile delle segnalazioni
                          Expanded(
                            child: CupertinoScrollbar(
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  ..._reports.map((report) =>
                                      _buildReportCard(report, isDark)),
                                  // Spazio extra in fondo per il pulsante
                                  const SizedBox(height: 80),
                                ],
                              ),
                            ),
                          ),
                          // Pulsante nuova segnalazione fisso in fondo
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background(isDark),
                              border: Border(
                                top: BorderSide(
                                  color: AppColors.borderColor(isDark)
                                      .withOpacity(0.1),
                                ),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: CupertinoButton.filled(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: _createNewReport,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.add_circled_solid,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Nuova segnalazione',
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildReportCard(Report report, bool isDark) {
    final category = report.category;
    final description = report.description;
    final date = report.createdAt;
    final lockerName = report.lockerName ?? 'N/A';
    final cellNumber = report.cellId;
    final hasPhoto = report.photoUrl != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.1),
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          final result = await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => ReportDetailPage(
                themeManager: widget.themeManager,
                report: {
                  'id': report.id,
                  'category': report.category,
                  'description': report.description,
                  'date': report.createdAt,
                  'lockerName': lockerName,
                  'cellNumber': cellNumber,
                  'hasPhoto': hasPhoto,
                  'lockerId': report.lockerId,
                  'cellId': report.cellId,
                },
                onReportDeleted: () {
                  _deleteReport(report.id);
                },
                onReportUpdated: () {
                  _refreshReports();
                },
              ),
            ),
          );
          
          // Se la segnalazione è stata modificata o cancellata, aggiorna la lista
          if (result == true) {
            _refreshReports();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con stato e data
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Categoria
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(isDark),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Locker e cella
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 14,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lockerName,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            if (cellNumber != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                CupertinoIcons.lock,
                                size: 14,
                                color: AppColors.textSecondary(isDark),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Cella $cellNumber',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Descrizione
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text(isDark),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Footer con foto e data
              Row(
                children: [
                  if (hasPhoto) ...[
                    Icon(
                      CupertinoIcons.photo,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Foto allegata',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    CupertinoIcons.clock,
                    size: 14,
                    color: AppColors.textSecondary(isDark),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: AppColors.textSecondary(isDark),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
