import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/reports/presentation/pages/report_issue_page.dart';
import 'package:app/features/reports/presentation/pages/report_detail_page.dart';

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
  // ⚠️ SOLO PER TESTING: Dati mock
  // IN PRODUZIONE: Caricare dal backend
  List<Map<String, dynamic>> _reports = [
    {
      'id': '1',
      'lockerName': 'Locker Centrale',
      'cellNumber': 'A-12',
      'category': 'Cella non si apre',
      'description': 'La cella non si apre quando premo il pulsante. Ho provato più volte ma non funziona.',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'hasPhoto': true,
    },
    {
      'id': '2',
      'lockerName': 'Locker Università',
      'cellNumber': 'B-05',
      'category': 'Cella danneggiata',
      'description': 'La porta della cella è danneggiata e non si chiude correttamente.',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'hasPhoto': false,
    },
    {
      'id': '3',
      'lockerName': 'Locker Stazione',
      'cellNumber': null,
      'category': 'Problema connessione Bluetooth',
      'description': 'Non riesco a connettermi al locker tramite Bluetooth. Il dispositivo non viene rilevato.',
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'hasPhoto': false,
    },
  ];

  bool _isLoading = false;

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

    // Se la segnalazione è stata inviata con successo, aggiungi alla lista
    if (result == true) {
      // ⚠️ SOLO PER TESTING: Aggiungi una segnalazione mock
      // IN PRODUZIONE: Ricarica dal backend
      setState(() {
        _reports.insert(
          0,
          {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'lockerName': 'Locker Generale',
            'cellNumber': null,
            'category': 'Altro',
            'description': 'Nuova segnalazione inviata',
            'date': DateTime.now(),
            'hasPhoto': false,
          },
        );
      });
    }
  }

  void _refreshReports() {
    // ⚠️ SOLO PER TESTING: Ricarica la lista
    // IN PRODUZIONE: Ricarica dal backend (GET /api/v1/reports)
    setState(() {
      // La lista viene aggiornata automaticamente quando si modifica un report
      // In produzione, qui si farebbe una chiamata API per ricaricare i dati
    });
  }

  void _deleteReport(String reportId) {
    // ⚠️ SOLO PER TESTING: Rimuovi la segnalazione dalla lista locale
    // IN PRODUZIONE: Cancella dal backend (DELETE /api/v1/reports/{id})
    setState(() {
      _reports.removeWhere((r) => r['id'] == reportId);
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

  Widget _buildReportCard(Map<String, dynamic> report, bool isDark) {
    final category = report['category'] as String;
    final description = report['description'] as String;
    final date = report['date'] as DateTime;
    final lockerName = report['lockerName'] as String;
    final cellNumber = report['cellNumber'] as String?;
    final hasPhoto = report['hasPhoto'] as bool;

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
                report: report,
                onReportDeleted: () {
                  _deleteReport(report['id'] as String);
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
