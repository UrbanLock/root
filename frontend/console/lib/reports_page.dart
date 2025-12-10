import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/features/reports/domain/models/report.dart';
import 'package:console/features/reports/data/mock_reports.dart';
import 'package:console/features/lockers/data/mock_lockers.dart';
import 'package:console/report_detail_page.dart';

class ReportsPage extends StatefulWidget {
  final ThemeManager themeManager;
  
  const ReportsPage({super.key, required this.themeManager});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Report> _allReports = [];
  List<Report> _filteredReports = [];
  String _searchQuery = '';
  ReportStatus? _selectedStatusFilter;
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadReports() {
    setState(() {
      _allReports = mockReports;
      _filteredReports = mockReports;
    });
  }

  void _changeReportStatus(Report report) {
    // Se è già conclusa, non può cambiare stato
    if (report.status == ReportStatus.conclusa) {
      return;
    }

    final nextStatus = report.status.nextStatus;
    final operatorName = 'Operatore'; // TODO: Recuperare dal login
    
    setState(() {
      // Trova il report nella lista e aggiorna lo stato
      final index = _allReports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        final updatedHistory = [
          ...report.statusHistory,
          StatusChangeHistory(
            operatorName: operatorName,
            changedAt: DateTime.now(),
            fromStatus: report.status,
            toStatus: nextStatus,
          ),
        ];
        
        final updatedReport = report.copyWith(
          status: nextStatus,
          statusHistory: updatedHistory,
        );
        
        _allReports[index] = updatedReport;
        _applyFilters();
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Report> filtered = _allReports;

    // Applica filtro ricerca
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((report) {
        // Cerca nel numero di segnalazione
        if (report.id.toLowerCase().contains(query)) return true;
        
        // Cerca nel locker/cella
        final locker = mockLockers.firstWhere(
          (l) => l.id == report.lockerId,
          orElse: () => mockLockers.first,
        );
        if (locker.name.toLowerCase().contains(query) ||
            locker.code.toLowerCase().contains(query)) return true;
        
        if (report.cellId != null) {
          final cellNumber = report.cellId!.split('_cell_').last;
          if (cellNumber.contains(query)) return true;
        }
        
        // Cerca nella categoria
        if (report.categoryLabel.toLowerCase().contains(query)) return true;
        
        // Cerca nella descrizione
        if (report.description.toLowerCase().contains(query)) return true;
        
        return false;
      }).toList();
    }

    // Applica filtro stato
    if (_selectedStatusFilter != null) {
      filtered = filtered.where((report) => report.status == _selectedStatusFilter).toList();
    }

    // Applica filtro categoria
    if (_selectedCategoryFilter != null) {
      filtered = filtered.where((report) => report.category == _selectedCategoryFilter).toList();
    }

    setState(() {
      _filteredReports = filtered;
    });
  }

  void _showStatusFilterDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filtra per stato'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Tutti gli stati'),
            onPressed: () {
              setState(() {
                _selectedStatusFilter = null;
                _applyFilters();
              });
              Navigator.pop(context);
            },
          ),
          ...ReportStatus.values.map((status) => CupertinoActionSheetAction(
            child: Text(status.label),
            onPressed: () {
              setState(() {
                _selectedStatusFilter = status;
                _applyFilters();
              });
              Navigator.pop(context);
            },
          )),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      ),
    );
  }

  void _showCategoryFilterDialog() {
    // Raccogli tutte le categorie uniche
    final categoryMap = <String, String>{};
    for (var report in _allReports) {
      if (!categoryMap.containsKey(report.category)) {
        categoryMap[report.category] = report.categoryLabel;
      }
    }
    final categories = categoryMap.entries.map((e) => {
      'id': e.key,
      'label': e.value,
    }).toList();
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filtra per categoria'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Tutte le categorie'),
            onPressed: () {
              setState(() {
                _selectedCategoryFilter = null;
                _applyFilters();
              });
              Navigator.pop(context);
            },
          ),
          ...categories.map((cat) => CupertinoActionSheetAction(
            child: Text(cat['label'] as String),
            onPressed: () {
              setState(() {
                _selectedCategoryFilter = cat['id'] as String;
                _applyFilters();
              });
              Navigator.pop(context);
            },
          )),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      ),
    );
  }

  String _getLockerInfo(Report report) {
    final locker = mockLockers.firstWhere(
      (l) => l.id == report.lockerId,
      orElse: () => mockLockers.first,
    );
    
    if (report.cellId != null) {
      // Estrai il numero della cella dall'ID
      final parts = report.cellId!.split('_cell_');
      if (parts.length > 1) {
        final cellNumber = parts.last;
        return '${locker.code} - Cella $cellNumber';
      }
      return '${locker.code} - ${report.cellId}';
    }
    
    return locker.code;
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
    
    return CupertinoPageScaffold(
      backgroundColor: isDark 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        middle: const Text('Segnalazioni'),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
          color: isDark ? CupertinoColors.white : CupertinoColors.black,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Barra di ricerca e filtri
            _buildSearchBar(isDark),
            
            // Lista segnalazioni
            Expanded(
              child: _filteredReports.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty || _selectedStatusFilter != null || _selectedCategoryFilter != null
                            ? 'Nessuna segnalazione trovata'
                            : 'Nessuna segnalazione disponibile',
                        style: TextStyle(
                          color: isDark 
                              ? CupertinoColors.white 
                              : CupertinoColors.black,
                        ),
                      ),
                    )
                  : _buildReportsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _searchController,
                  placeholder: 'Cerca per locker, cella, categoria...',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? CupertinoColors.darkBackgroundGray 
                        : CupertinoColors.white,
                    border: Border.all(
                      color: CupertinoColors.separator,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(
                      CupertinoIcons.search,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showStatusFilterDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedStatusFilter != null
                          ? AppColors.primary
                          : (isDark 
                              ? CupertinoColors.darkBackgroundGray 
                              : CupertinoColors.white),
                      border: Border.all(
                        color: _selectedStatusFilter != null
                            ? AppColors.primary
                            : CupertinoColors.separator,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.circle_grid_3x3,
                          size: 16,
                          color: _selectedStatusFilter != null
                              ? AppColors.white
                              : (isDark ? CupertinoColors.white : CupertinoColors.black),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedStatusFilter?.label ?? 'Stato',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedStatusFilter != null
                                ? AppColors.white
                                : (isDark ? CupertinoColors.white : CupertinoColors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showCategoryFilterDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedCategoryFilter != null
                          ? AppColors.primary
                          : (isDark 
                              ? CupertinoColors.darkBackgroundGray 
                              : CupertinoColors.white),
                      border: Border.all(
                        color: _selectedCategoryFilter != null
                            ? AppColors.primary
                            : CupertinoColors.separator,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.slider_horizontal_3,
                          size: 16,
                          color: _selectedCategoryFilter != null
                              ? AppColors.white
                              : (isDark ? CupertinoColors.white : CupertinoColors.black),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _selectedCategoryFilter != null
                                ? _allReports.firstWhere((r) => r.category == _selectedCategoryFilter).categoryLabel
                                : 'Categoria',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedCategoryFilter != null
                                  ? AppColors.white
                                  : (isDark ? CupertinoColors.white : CupertinoColors.black),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredReports.length,
      itemBuilder: (context, index) {
        final report = _filteredReports[index];
        return _buildReportItem(report, isDark);
      },
    );
  }

  Widget _buildReportItem(Report report, bool isDark) {
    final statusColor = _getStatusColor(report.status);
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        // Trova il report aggiornato dalla lista
        final updatedReport = _allReports.firstWhere(
          (r) => r.id == report.id,
          orElse: () => report,
        );
        await Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => ReportDetailPage(
              report: updatedReport,
              themeManager: widget.themeManager,
            ),
          ),
        );
        // Ricarica i report quando si torna indietro per vedere gli aggiornamenti
        _loadReports();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Segnalazione ${report.id.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark 
                            ? CupertinoColors.white 
                            : CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location,
                          size: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getLockerInfo(report),
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
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
                      report.status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (report.status != ReportStatus.conclusa) ...[
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: () => _changeReportStatus(report),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.tag,
                size: 14,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 6),
              Text(
                report.categoryLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.description,
            style: TextStyle(
              fontSize: 14,
              color: isDark 
                  ? CupertinoColors.white 
                  : CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 14,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 6),
              Text(
                '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year} ${report.createdAt.hour}:${report.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

