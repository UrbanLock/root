import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/features/lockers/domain/models/locker.dart';
import 'package:console/features/lockers/domain/models/locker_cell.dart';
import 'package:console/features/lockers/domain/models/cell_type.dart';
import 'package:console/features/lockers/domain/repositories/locker_repository.dart';
import 'package:console/features/lockers/data/repositories/locker_repository_mock.dart';
import 'package:console/features/reports/domain/models/report.dart';
import 'package:console/features/reports/data/mock_reports.dart';

class LockerDetailPage extends StatefulWidget {
  final Locker locker;
  final ThemeManager themeManager;
  
  const LockerDetailPage({
    super.key,
    required this.locker,
    required this.themeManager,
  });

  @override
  State<LockerDetailPage> createState() => _LockerDetailPageState();
}

class _LockerDetailPageState extends State<LockerDetailPage> {
  final LockerRepository _lockerRepository = LockerRepositoryMock();
  
  late Locker _currentLocker;
  List<LockerCell> _cells = [];
  bool _isLoading = true;
  CellType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _currentLocker = widget.locker;
    _loadCells();
  }

  void _toggleLockerStatus() {
    // Se il locker è online e si vuole metterlo offline, mostra il dialog
    if (_currentLocker.isOnline) {
      _showOfflineDialog();
    } else {
      // Se è offline, lo metti direttamente online
      _updateLockerStatus(false);
    }
  }

  void _updateLockerStatus(bool skipDialog) {
    setState(() {
      // Crea una nuova istanza del locker con lo stato invertito
      _currentLocker = Locker(
        id: _currentLocker.id,
        name: _currentLocker.name,
        code: _currentLocker.code,
        type: _currentLocker.type,
        totalCells: _currentLocker.totalCells,
        availableCells: _currentLocker.availableCells,
        isActive: _currentLocker.isActive,
        isOnline: !_currentLocker.isOnline,
        description: _currentLocker.description,
        cells: _currentLocker.cells,
        cellStats: _currentLocker.cellStats,
      );
      
      // Aggiorna tutte le celle con lo stesso stato del locker
      _cells = _cells.map((cell) {
        return LockerCell(
          id: cell.id,
          cellNumber: cell.cellNumber,
          type: cell.type,
          size: cell.size,
          isAvailable: _currentLocker.isOnline, // Le celle prendono lo stato del locker
          pricePerHour: cell.pricePerHour,
          pricePerDay: cell.pricePerDay,
          itemName: cell.itemName,
          itemDescription: cell.itemDescription,
          itemImageUrl: cell.itemImageUrl,
          storeName: cell.storeName,
          availableUntil: cell.availableUntil,
          borrowDuration: cell.borrowDuration,
        );
      }).toList();
    });
  }

  void _showOfflineDialog() {
    String? selectedReason; // 'manutenzione' o 'segnalazione'
    Report? selectedReport;
    final isDark = widget.themeManager.isDarkMode;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filtra le segnalazioni per questo locker (solo quelle senza cellId, quindi del locker intero)
          final lockerReports = mockReports.where((r) => 
            r.lockerId == _currentLocker.id && r.cellId == null
          ).toList();
          
          return CupertinoAlertDialog(
            title: const Text('Motivo del cambio di stato'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Seleziona il motivo:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Opzione Manutenzione
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setDialogState(() {
                        selectedReason = 'manutenzione';
                        selectedReport = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedReason == 'manutenzione'
                            ? AppColors.primary.withOpacity(0.2)
                            : (isDark 
                                ? CupertinoColors.darkBackgroundGray 
                                : CupertinoColors.white),
                        border: Border.all(
                          color: selectedReason == 'manutenzione'
                              ? AppColors.primary
                              : CupertinoColors.separator,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == 'manutenzione'
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle,
                            color: selectedReason == 'manutenzione'
                                ? AppColors.primary
                                : CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 12),
                          const Text('Manutenzione'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Opzione Segnalazione
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setDialogState(() {
                        selectedReason = 'segnalazione';
                        selectedReport = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedReason == 'segnalazione'
                            ? AppColors.primary.withOpacity(0.2)
                            : (isDark 
                                ? CupertinoColors.darkBackgroundGray 
                                : CupertinoColors.white),
                        border: Border.all(
                          color: selectedReason == 'segnalazione'
                              ? AppColors.primary
                              : CupertinoColors.separator,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == 'segnalazione'
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle,
                            color: selectedReason == 'segnalazione'
                                ? AppColors.primary
                                : CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 12),
                          const Text('Segnalazione'),
                        ],
                      ),
                    ),
                  ),
                  // Lista segnalazioni (solo se segnalazione è selezionata)
                  if (selectedReason == 'segnalazione') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Seleziona una segnalazione:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (lockerReports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Nessuna segnalazione disponibile per questo locker',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: lockerReports.map((report) {
                              final isSelected = selectedReport?.id == report.id;
                              return CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setDialogState(() {
                                    selectedReport = report;
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.2)
                                        : (isDark 
                                            ? CupertinoColors.darkBackgroundGray 
                                            : CupertinoColors.white),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : CupertinoColors.separator,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? CupertinoIcons.check_mark_circled_solid
                                                : CupertinoIcons.circle,
                                            color: isSelected
                                                ? AppColors.primary
                                                : CupertinoColors.systemGrey,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              report.categoryLabel,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark 
                                                    ? CupertinoColors.white 
                                                    : CupertinoColors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        report.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annulla'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  // Valida che i campi siano selezionati
                  if (selectedReason == null) {
                    return; // Non fare nulla se non è selezionato il motivo
                  }
                  if (selectedReason == 'segnalazione' && selectedReport == null) {
                    return; // Non fare nulla se è segnalazione ma non è selezionata una segnalazione
                  }
                  
                  // Se tutto è valido, chiudi il dialog e aggiorna lo stato
                  Navigator.of(context).pop();
                  _updateLockerStatus(false);
                },
                child: Text(
                  'Conferma',
                  style: TextStyle(
                    color: (selectedReason != null && 
                            (selectedReason != 'segnalazione' || selectedReport != null))
                        ? AppColors.primary
                        : CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleCellStatus(LockerCell cell) {
    // Se la cella è disponibile e si vuole renderla non disponibile, mostra il dialog
    if (cell.isAvailable) {
      _showCellOfflineDialog(cell);
    } else {
      // Se è non disponibile, la rendi direttamente disponibile
      _updateCellStatus(cell, false);
    }
  }

  void _updateCellStatus(LockerCell cell, bool skipDialog) {
    setState(() {
      final index = _cells.indexWhere((c) => c.id == cell.id);
      if (index != -1) {
        // Crea una nuova istanza della cella con lo stato invertito
        final updatedCell = LockerCell(
          id: cell.id,
          cellNumber: cell.cellNumber,
          type: cell.type,
          size: cell.size,
          isAvailable: !cell.isAvailable, // Inverti solo questa cella
          pricePerHour: cell.pricePerHour,
          pricePerDay: cell.pricePerDay,
          itemName: cell.itemName,
          itemDescription: cell.itemDescription,
          itemImageUrl: cell.itemImageUrl,
          storeName: cell.storeName,
          availableUntil: cell.availableUntil,
          borrowDuration: cell.borrowDuration,
        );
        _cells[index] = updatedCell;
      }
    });
  }

  void _showCellOfflineDialog(LockerCell cell) {
    String? selectedReason; // 'manutenzione' o 'segnalazione'
    Report? selectedReport;
    final isDark = widget.themeManager.isDarkMode;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filtra le segnalazioni per questo locker che riguardano celle (non il locker intero)
          final allCellReports = mockReports.where((r) => 
            r.lockerId == _currentLocker.id && r.cellId != null
          ).toList();
          
          // Raggruppa per categoria e prendi solo una segnalazione per categoria
          final Map<String, Report> uniqueReportsByCategory = {};
          for (var report in allCellReports) {
            if (!uniqueReportsByCategory.containsKey(report.category)) {
              uniqueReportsByCategory[report.category] = report;
            }
          }
          final cellReports = uniqueReportsByCategory.values.toList();
          
          return CupertinoAlertDialog(
            title: Text('Motivo del cambio di stato - ${cell.cellNumber}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Seleziona il motivo:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Opzione Manutenzione
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setDialogState(() {
                        selectedReason = 'manutenzione';
                        selectedReport = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedReason == 'manutenzione'
                            ? AppColors.primary.withOpacity(0.2)
                            : (isDark 
                                ? CupertinoColors.darkBackgroundGray 
                                : CupertinoColors.white),
                        border: Border.all(
                          color: selectedReason == 'manutenzione'
                              ? AppColors.primary
                              : CupertinoColors.separator,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == 'manutenzione'
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle,
                            color: selectedReason == 'manutenzione'
                                ? AppColors.primary
                                : CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 12),
                          const Text('Manutenzione'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Opzione Segnalazione
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setDialogState(() {
                        selectedReason = 'segnalazione';
                        selectedReport = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedReason == 'segnalazione'
                            ? AppColors.primary.withOpacity(0.2)
                            : (isDark 
                                ? CupertinoColors.darkBackgroundGray 
                                : CupertinoColors.white),
                        border: Border.all(
                          color: selectedReason == 'segnalazione'
                              ? AppColors.primary
                              : CupertinoColors.separator,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == 'segnalazione'
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle,
                            color: selectedReason == 'segnalazione'
                                ? AppColors.primary
                                : CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 12),
                          const Text('Segnalazione'),
                        ],
                      ),
                    ),
                  ),
                  // Lista segnalazioni (solo se segnalazione è selezionata)
                  if (selectedReason == 'segnalazione') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Seleziona una segnalazione:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (cellReports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Nessuna segnalazione disponibile per questa cella',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: cellReports.map((report) {
                              final isSelected = selectedReport?.id == report.id;
                              return CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setDialogState(() {
                                    selectedReport = report;
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.2)
                                        : (isDark 
                                            ? CupertinoColors.darkBackgroundGray 
                                            : CupertinoColors.white),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : CupertinoColors.separator,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? CupertinoIcons.check_mark_circled_solid
                                                : CupertinoIcons.circle,
                                            color: isSelected
                                                ? AppColors.primary
                                                : CupertinoColors.systemGrey,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              report.categoryLabel,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark 
                                                    ? CupertinoColors.white 
                                                    : CupertinoColors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        report.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annulla'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  // Valida che i campi siano selezionati
                  if (selectedReason == null) {
                    return; // Non fare nulla se non è selezionato il motivo
                  }
                  if (selectedReason == 'segnalazione' && selectedReport == null) {
                    return; // Non fare nulla se è segnalazione ma non è selezionata una segnalazione
                  }
                  
                  // Se tutto è valido, chiudi il dialog e aggiorna lo stato
                  Navigator.of(context).pop();
                  _updateCellStatus(cell, false);
                },
                child: Text(
                  'Conferma',
                  style: TextStyle(
                    color: (selectedReason != null && 
                            (selectedReason != 'segnalazione' || selectedReport != null))
                        ? AppColors.primary
                        : CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadCells() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final cells = await _lockerRepository.getLockerCells(widget.locker.id);
      setState(() {
        // Se il locker è offline, tutte le celle devono essere offline
        _cells = cells.map((cell) {
          return LockerCell(
            id: cell.id,
            cellNumber: cell.cellNumber,
            type: cell.type,
            size: cell.size,
            isAvailable: _currentLocker.isOnline ? cell.isAvailable : false,
            pricePerHour: cell.pricePerHour,
            pricePerDay: cell.pricePerDay,
            itemName: cell.itemName,
            itemDescription: cell.itemDescription,
            itemImageUrl: cell.itemImageUrl,
            storeName: cell.storeName,
            availableUntil: cell.availableUntil,
            borrowDuration: cell.borrowDuration,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<LockerCell> get _filteredCells {
    if (_selectedFilter == null) {
      return _cells;
    }
    return _cells.where((cell) => cell.type == _selectedFilter).toList();
  }

  void _showFilterDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filtra per tipo'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Tutti i tipi'),
            onPressed: () {
              setState(() {
                _selectedFilter = null;
              });
              Navigator.pop(context);
            },
          ),
          ...CellType.values.map((type) => CupertinoActionSheetAction(
            child: Text(type.label),
            onPressed: () {
              setState(() {
                _selectedFilter = type;
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
        middle: Text(
          _currentLocker.name,
          style: TextStyle(
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
          ),
        ),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(_currentLocker),
          color: isDark ? CupertinoColors.white : CupertinoColors.black,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header con info locker
            _buildLockerHeader(isDark),
            
            // Barra filtri
            _buildFilterBar(isDark),
            
            // Lista celle
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _filteredCells.isEmpty
                      ? Center(
                          child: Text(
                            _selectedFilter != null
                                ? 'Nessuna cella trovata per questo tipo'
                                : 'Nessuna cella disponibile',
                            style: TextStyle(
                              color: isDark 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            ),
                          ),
                        )
                      : _buildCellsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockerHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.locker.type.icon,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.locker.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark 
                            ? CupertinoColors.white 
                            : CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.locker.code,
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
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
                      color: _currentLocker.isOnline
                          ? CupertinoColors.systemGreen.withOpacity(0.2)
                          : CupertinoColors.systemRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _currentLocker.isOnline
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentLocker.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _currentLocker.isOnline
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: _toggleLockerStatus,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CupertinoIcons.power,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.locker.description != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.locker.description!,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.square_grid_2x2,
                size: 16,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.locker.availableCells}/${widget.locker.totalCells} celle disponibili',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_filteredCells.length} celle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark 
                    ? CupertinoColors.white 
                    : CupertinoColors.black,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _showFilterDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedFilter != null
                    ? AppColors.primary
                    : (isDark 
                        ? CupertinoColors.darkBackgroundGray 
                        : CupertinoColors.white),
                border: Border.all(
                  color: _selectedFilter != null
                      ? AppColors.primary
                      : CupertinoColors.separator,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 16,
                    color: _selectedFilter != null
                        ? AppColors.white
                        : (isDark ? CupertinoColors.white : CupertinoColors.black),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedFilter?.label ?? 'Filtri',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedFilter != null
                          ? AppColors.white
                          : (isDark ? CupertinoColors.white : CupertinoColors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellsList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCells.length,
      itemBuilder: (context, index) {
        final cell = _filteredCells[index];
        return _buildCellCard(cell, isDark);
      },
    );
  }

  Widget _buildCellCard(LockerCell cell, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cell.isAvailable
              ? CupertinoColors.separator
              : CupertinoColors.systemRed.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                cell.type.icon,
                color: cell.isAvailable 
                    ? AppColors.primary 
                    : CupertinoColors.systemGrey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cell.cellNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark 
                            ? CupertinoColors.white 
                            : CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cell.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cell.isAvailable
                          ? CupertinoColors.systemGreen.withOpacity(0.2)
                          : CupertinoColors.systemRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cell.isAvailable ? 'Disponibile' : 'Occupata',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cell.isAvailable
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.systemRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: () => _toggleCellStatus(cell),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CupertinoIcons.power,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.square,
                size: 14,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 6),
              Text(
                cell.size.label,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              if (cell.type == CellType.deposit) ...[
                const SizedBox(width: 16),
                Icon(
                  CupertinoIcons.money_dollar,
                  size: 14,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  '€${cell.pricePerHour.toStringAsFixed(2)}/h - €${cell.pricePerDay.toStringAsFixed(2)}/g',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ],
          ),
          if (cell.itemName != null) ...[
            const SizedBox(height: 8),
            Text(
              cell.itemName!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark 
                    ? CupertinoColors.white 
                    : CupertinoColors.black,
              ),
            ),
          ],
          if (cell.itemDescription != null) ...[
            const SizedBox(height: 4),
            Text(
              cell.itemDescription!,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
          if (cell.storeName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  CupertinoIcons.building_2_fill,
                  size: 14,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  cell.storeName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ],
          if (cell.availableUntil != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: 14,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  'Disponibile fino a: ${_formatDateTime(cell.availableUntil!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ],
          if (cell.borrowDuration != null) ...[
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
                  'Durata prestito: ${_formatDuration(cell.borrowDuration!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'giorno' : 'giorni'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'ora' : 'ore'}';
    } else {
      return '${duration.inMinutes} minuti';
    }
  }
}

