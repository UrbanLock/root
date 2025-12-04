import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/reports/presentation/pages/report_issue_page.dart';

/// Pagina che mostra lo storico delle celle utilizzate
/// 
/// Mostra tutte le celle che l'utente ha completato (restituite, ritirate, ecc.)
/// 
/// **TODO quando il backend sarà pronto:**
/// - Caricare storico dal backend (GET /api/v1/cells/history)
/// - Paginazione per grandi quantità di dati
/// - Filtri per tipo di utilizzo
class HistoryPage extends StatefulWidget {
  final ThemeManager themeManager;

  const HistoryPage({
    super.key,
    required this.themeManager,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ActiveCell> _history = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  static const int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Carica lo storico delle celle
  /// 
  /// **TODO BACKEND**: Sostituire con chiamata API reale
  /// GET /api/v1/cells/history?page=1&limit=20
  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ⚠️ SOLO PER TESTING: Usa repository mock
      // IN PRODUZIONE: Il repository reale farà chiamate HTTP
      final repository = AppDependencies.cellRepository;
      if (repository != null) {
        _history = await repository.getHistory(page: _currentPage, limit: _itemsPerPage);
      } else {
        _history = [];
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Formatta la data per la visualizzazione
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Oggi';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Formatta l'orario per la visualizzazione
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Ottiene l'icona in base al tipo di utilizzo
  IconData _getIconForType(CellUsageType type) {
    switch (type) {
      case CellUsageType.borrowed:
        return CupertinoIcons.arrow_down_circle;
      case CellUsageType.deposited:
        return CupertinoIcons.lock;
      case CellUsageType.pickup:
        return CupertinoIcons.cart_fill;
    }
  }

  /// Ottiene il label del tipo di utilizzo
  String _getTypeLabel(CellUsageType type) {
    switch (type) {
      case CellUsageType.borrowed:
        return 'Prestito';
      case CellUsageType.deposited:
        return 'Deposito';
      case CellUsageType.pickup:
        return 'Ritiro ordine';
    }
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
              'Storico utilizzi',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
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
                                onPressed: _loadHistory,
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _history.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.clock,
                                    size: 64,
                                    color: AppColors.textSecondary(isDark).withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Nessun utilizzo',
                                    style: AppTextStyles.title(isDark),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'I tuoi utilizzi dei lockers appariranno qui',
                                    style: AppTextStyles.bodySecondary(isDark),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : CustomScrollView(
                            slivers: [
                              CupertinoSliverRefreshControl(
                                onRefresh: _loadHistory,
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.all(20),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      if (index == 0) {
                                        // Header
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'I tuoi utilizzi',
                                              style: AppTextStyles.title(isDark),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Visualizza la cronologia dei lockers che hai utilizzato',
                                              style: AppTextStyles.bodySecondary(isDark),
                                            ),
                                            const SizedBox(height: 20),
                                          ],
                                        );
                                      }
                                      
                                      final cell = _history[index - 1];
                                      final isLast = index == _history.length;
                                      
                                      return _buildHistoryItem(
                                        context: context,
                                        isDark: isDark,
                                        cell: cell,
                                      );
                                    },
                                    childCount: _history.length + 1,
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

  Widget _buildHistoryItem({
    required BuildContext context,
    required bool isDark,
    required ActiveCell cell,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.1),
        ),
      ),
      child: Stack(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              // TODO: Mostra dettagli utilizzo
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 50, 16), // Padding extra a destra per il pulsante
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary(isDark).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconForType(cell.type),
                      size: 28,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cell.lockerName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              _getIconForType(cell.type),
                              size: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _getTypeLabel(cell.type),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary(isDark),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary(isDark),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.lock,
                              size: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                cell.cellNumber,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary(isDark),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.calendar,
                              size: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${_formatDate(cell.startTime)} • ${_formatTime(cell.startTime)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(isDark),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Badge completato in verde
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                size: 12,
                                color: CupertinoColors.systemGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Completato',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: CupertinoColors.systemGreen,
                                  fontWeight: FontWeight.w600,
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
          // Pulsante segnala problema in alto a destra
          Positioned(
            top: 8,
            right: 8,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => ReportIssuePage(
                      themeManager: widget.themeManager,
                      lockerId: cell.lockerId,
                      lockerName: cell.lockerName,
                      cellId: cell.cellId,
                      cellNumber: cell.cellNumber,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.borderColor(isDark).withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 16,
                  color: CupertinoColors.systemOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
