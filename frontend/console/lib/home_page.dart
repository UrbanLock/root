import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/features/lockers/domain/models/locker.dart';
import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/features/lockers/domain/repositories/locker_repository.dart';
import 'package:console/features/lockers/data/repositories/locker_repository_api.dart';
import 'package:console/features/reports/domain/models/report.dart';
import 'package:console/features/reports/data/mock_reports.dart';
import 'package:console/locker_detail_page.dart';
import 'package:console/reports_page.dart';
import 'package:console/donations_page.dart';
import 'package:console/analytics_page.dart';
import 'package:console/rental_cells_page.dart';
import 'package:console/core/api/operator_auth_service.dart';
import 'package:console/login_page.dart';

class HomePage extends StatefulWidget {
  final ThemeManager themeManager;
  
  const HomePage({super.key, required this.themeManager});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LockerRepository _lockerRepository = LockerRepositoryApi();
  final TextEditingController _searchController = TextEditingController();
  
  List<Locker> _allLockers = [];
  List<Locker> _filteredLockers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  LockerType? _selectedFilter;
  String? _hoveredButton;

  void _toggleLockerStatus(Locker locker) {
    // Se il locker è online e si vuole metterlo offline, mostra il dialog
    if (locker.isOnline) {
      _showOfflineDialog(locker);
    } else {
      // Se è offline, lo metti direttamente online
      _updateLockerStatus(locker, false);
    }
  }

  Future<void> _updateLockerStatus(Locker locker, bool skipDialog) async {
    final newStatus = !locker.isOnline;
    
    try {
      // Aggiorna lo stato nel database
      final success = await _lockerRepository.updateLockerStatus(locker.id, newStatus);
      
      if (success) {
        // Aggiorna lo stato localmente solo se la chiamata API è riuscita
        setState(() {
          final index = _allLockers.indexWhere((l) => l.id == locker.id);
          if (index != -1) {
            final updatedLocker = Locker(
              id: locker.id,
              name: locker.name,
              code: locker.code,
              type: locker.type,
              totalCells: locker.totalCells,
              availableCells: locker.availableCells,
              isActive: locker.isActive,
              isOnline: newStatus,
              description: locker.description,
              cells: locker.cells,
              cellStats: locker.cellStats,
            );
            _allLockers[index] = updatedLocker;
            _applyFilters();
          }
        });
      } else {
        // Mostra un messaggio di errore
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Errore'),
              content: const Text('Impossibile aggiornare lo stato del locker. Riprova più tardi.'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Mostra un messaggio di errore
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Errore'),
            content: Text('Errore durante l\'aggiornamento: ${e.toString()}'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showOfflineDialog(Locker locker) {
    String? selectedReason; // 'manutenzione' o 'segnalazione'
    Report? selectedReport;
    final isDark = widget.themeManager.isDarkMode;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filtra le segnalazioni per questo locker (solo quelle senza cellId, quindi del locker intero)
          final lockerReports = mockReports.where((r) => 
            r.lockerId == locker.id && r.cellId == null
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
                  _updateLockerStatus(locker, false);
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

  @override
  void initState() {
    super.initState();
    _loadLockers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLockers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final lockers = await _lockerRepository.getLockers();
      setState(() {
        _allLockers = lockers;
        _filteredLockers = lockers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Locker> filtered = _allLockers;

    // Applica filtro ricerca
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((locker) {
        return locker.name.toLowerCase().contains(query) ||
               locker.code.toLowerCase().contains(query) ||
               locker.type.label.toLowerCase().contains(query) ||
               (locker.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Applica filtro categoria
    if (_selectedFilter != null) {
      filtered = filtered.where((locker) => locker.type == _selectedFilter).toList();
    }

    setState(() {
      _filteredLockers = filtered;
    });
  }

  void _showFilterDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filtra per categoria'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Tutte le categorie'),
            onPressed: () {
              setState(() {
                _selectedFilter = null;
                _applyFilters();
              });
              Navigator.pop(context);
            },
          ),
          ...LockerType.values.map((type) => CupertinoActionSheetAction(
            child: Text(type.label),
            onPressed: () {
              setState(() {
                _selectedFilter = type;
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.isDarkMode;
    
    return CupertinoPageScaffold(
      backgroundColor: isDark 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Barra di navigazione superiore
            _buildNavigationBar(isDark),
            
            // Barra di ricerca e filtri
            _buildSearchBar(isDark),
            
            // Lista locker
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _filteredLockers.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty || _selectedFilter != null
                                ? 'Nessun locker trovato'
                                : 'Nessun locker disponibile',
                            style: TextStyle(
                              color: isDark 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            ),
                          ),
                        )
                      : _buildLockerList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout() {
    final isDark = widget.themeManager.isDarkMode;
    final navigatorContext = Navigator.of(context);
    
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Conferma Logout'),
        content: const Text('Sei sicuro di voler effettuare il logout?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              // Chiudi il dialog
              Navigator.of(dialogContext).pop();
              
              // Esegui logout
              await OperatorAuthService.logout();
              
              // Reindirizza alla pagina di login usando il context principale
              if (mounted) {
                navigatorContext.pushAndRemoveUntil(
                  CupertinoPageRoute(
                    builder: (context) => LoginPage(themeManager: widget.themeManager),
                  ),
                  (route) => false, // Rimuovi tutte le route precedenti
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(bool isDark) {
    final buttons = [
      {'label': 'Home', 'icon': CupertinoIcons.house_fill, 'route': null},
      {'label': 'Crea Locker', 'icon': CupertinoIcons.add_circled, 'route': null},
      {'label': 'Donazioni', 'icon': CupertinoIcons.heart_fill, 'route': 'donations'},
      {'label': 'Segnalazioni', 'icon': CupertinoIcons.exclamationmark_triangle_fill, 'route': 'reports'},
      {'label': 'Affitto Celle', 'icon': CupertinoIcons.calendar, 'route': 'rental'},
      {'label': 'Analytics', 'icon': CupertinoIcons.chart_bar_fill, 'route': null},
      {'label': 'Logout', 'icon': CupertinoIcons.power, 'route': 'logout'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
      child: Row(
        children: buttons.map((button) {
          final isHovered = _hoveredButton == button['label'];
          return Expanded(
            child: MouseRegion(
              onEnter: (_) {
                setState(() {
                  _hoveredButton = button['label'] as String;
                });
              },
              onExit: (_) {
                setState(() {
                  _hoveredButton = null;
                });
              },
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: () {
                  final route = button['route'] as String?;
                  if (route == 'logout') {
                    _handleLogout();
                  } else if (route == 'reports') {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => ReportsPage(themeManager: widget.themeManager),
                      ),
                    );
                  } else if (route == 'donations') {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => DonationsPage(themeManager: widget.themeManager),
                      ),
                    );
                  } else if (route == 'rental') {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => RentalCellsPage(themeManager: widget.themeManager),
                      ),
                    );
                  } else if (button['label'] == 'Analytics') {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => AnalyticsPage(themeManager: widget.themeManager),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? AppColors.primary.withOpacity(0.2)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        button['icon'] as IconData,
                        size: 18,
                        color: isHovered
                            ? AppColors.primary
                            : (isDark ? CupertinoColors.white : CupertinoColors.black),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          button['label'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                            color: isHovered
                                ? AppColors.primary
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
          );
        }).toList(),
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
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _searchController,
              placeholder: 'Cerca per nome, codice o categoria...',
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
          const SizedBox(width: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _showFilterDialog,
            child: Container(
              padding: const EdgeInsets.all(12),
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
              child: Icon(
                CupertinoIcons.slider_horizontal_3,
                color: _selectedFilter != null
                    ? AppColors.white
                    : (isDark ? CupertinoColors.white : CupertinoColors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockerList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLockers.length,
      itemBuilder: (context, index) {
        final locker = _filteredLockers[index];
        return _buildLockerCard(locker, isDark);
      },
    );
  }

  Widget _buildLockerCard(Locker locker, bool isDark) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        // Trova il locker aggiornato dalla lista
        final updatedLocker = _allLockers.firstWhere(
          (l) => l.id == locker.id,
          orElse: () => locker,
        );
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => LockerDetailPage(
              locker: updatedLocker,
              themeManager: widget.themeManager,
            ),
          ),
        ).then((returnedLocker) {
          // Se viene ritornato un locker aggiornato, aggiorna la lista
          if (returnedLocker != null && returnedLocker is Locker) {
            setState(() {
              final index = _allLockers.indexWhere((l) => l.id == returnedLocker.id);
              if (index != -1) {
                _allLockers[index] = returnedLocker;
                _applyFilters();
              }
            });
          }
        });
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
              Icon(
                locker.type.icon,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locker.name,
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
                      locker.code,
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
                      color: locker.isOnline
                          ? CupertinoColors.systemGreen.withOpacity(0.2)
                          : CupertinoColors.systemRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: locker.isOnline
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          locker.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: locker.isOnline
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
                    onPressed: () => _toggleLockerStatus(locker),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        locker.isOnline 
                            ? CupertinoIcons.power
                            : CupertinoIcons.power,
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
                CupertinoIcons.tag,
                size: 14,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 6),
              Text(
                locker.type.label,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                CupertinoIcons.square_grid_2x2,
                size: 14,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 6),
              Text(
                '${locker.availableCells}/${locker.totalCells} celle disponibili',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          if (locker.description != null) ...[
            const SizedBox(height: 8),
            Text(
              locker.description!,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      ),
    );
  }
}

