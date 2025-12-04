import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/reports/presentation/pages/report_issue_page.dart';

/// Pagina di dettaglio di una singola segnalazione
/// 
/// Mostra tutti i dettagli della segnalazione:
/// - Categoria del problema
/// - Descrizione completa
/// - Locker e cella (se presente)
/// - Data e ora di invio
/// - Stato attuale
/// - Foto se presente
/// 
/// **TODO quando il backend sarà pronto:**
/// - Caricare dettagli dal backend (GET /api/v1/reports/{id})
/// - Mostrare aggiornamenti/commenti se presenti
/// - Permettere di aggiungere commenti
class ReportDetailPage extends StatelessWidget {
  final ThemeManager themeManager;
  final Map<String, dynamic> report;
  final VoidCallback? onReportDeleted;
  final VoidCallback? onReportUpdated;

  const ReportDetailPage({
    super.key,
    required this.themeManager,
    required this.report,
    this.onReportDeleted,
    this.onReportUpdated,
  });


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
      return '${date.day}/${date.month}/${date.year} alle ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, _) {
        final isDark = themeManager.isDarkMode;
        final category = report['category'] as String;
        final description = report['description'] as String;
        final date = report['date'] as DateTime;
        final lockerName = report['lockerName'] as String;
        final cellNumber = report['cellNumber'] as String?;
        final hasPhoto = report['hasPhoto'] as bool;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: Text(
              'Dettaglio segnalazione',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  
                  // Categoria
                  Text(
                    'Categoria',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Descrizione
                  Text(
                    'Descrizione',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.text(isDark),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Informazioni locker e cella
                  Text(
                    'Informazioni',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 18,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lockerName,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.text(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (cellNumber != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.lock,
                                size: 18,
                                color: AppColors.textSecondary(isDark),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cella $cellNumber',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.text(isDark),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Data e ora
                  Text(
                    'Data e ora',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 18,
                          color: AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Foto (se presente)
                  if (hasPhoto) ...[
                    Text(
                      'Foto allegata',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.borderColor(isDark).withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.photo,
                            size: 24,
                            color: AppColors.primary(isDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Foto disponibile',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.text(isDark),
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Spazio extra in fondo
                  const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Pulsanti modifica e cancella fissi in basso
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background(isDark),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        // Pulsante cancella (a sinistra)
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            color: CupertinoColors.systemRed,
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () {
                              _showDeleteConfirmation(context, isDark);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.delete,
                                  size: 18,
                                  color: CupertinoColors.white,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Cancella',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Pulsante modifica (a destra)
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            color: AppColors.primary(isDark),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) => ReportIssuePage(
                                    themeManager: themeManager,
                                    lockerId: report['lockerId'] as String?,
                                    lockerName: lockerName,
                                    cellId: report['cellId'] as String?,
                                    cellNumber: cellNumber,
                                    reportId: report['id'] as String?,
                                    existingReport: report,
                                  ),
                                ),
                              );
                              
                              // Se la modifica è stata salvata, aggiorna
                              if (result == true && context.mounted) {
                                onReportUpdated?.call();
                                Navigator.of(context).pop(true);
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.pencil,
                                  size: 18,
                                  color: CupertinoColors.white,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Modifica',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  void _showDeleteConfirmation(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Conferma cancellazione'),
        content: const Text(
          'Sei sicuro di voler cancellare questa segnalazione? Questa azione non può essere annullata.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop(); // Chiudi dialog
              onReportDeleted?.call();
              if (context.mounted) {
                Navigator.of(context).pop(true); // Torna alla lista
              }
            },
            child: const Text('Cancella'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
  }
}

