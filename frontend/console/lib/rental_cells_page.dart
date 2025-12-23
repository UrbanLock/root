import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/features/lockers/domain/models/locker.dart';
import 'package:console/features/lockers/domain/models/locker_cell.dart';
import 'package:console/features/lockers/domain/models/cell_type.dart';
import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/features/lockers/domain/repositories/locker_repository.dart';
import 'package:console/features/lockers/data/repositories/locker_repository_api.dart';

class RentalCellsPage extends StatefulWidget {
  final ThemeManager themeManager;
  
  const RentalCellsPage({super.key, required this.themeManager});

  @override
  State<RentalCellsPage> createState() => _RentalCellsPageState();
}

class _RentalCellsPageState extends State<RentalCellsPage> {
  final LockerRepository _lockerRepository = LockerRepositoryApi();
  final TextEditingController _searchController = TextEditingController();
  
  List<Locker> _allLockers = [];
  List<Locker> _filteredLockers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Locker? _selectedLocker;
  List<LockerCell> _rentalCells = [];
  bool _isLoadingCells = false;
  // Mappa per tracciare le informazioni di affitto: cellId -> {companyName, taxCode}
  final Map<String, Map<String, String>> _rentalInfo = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadLockers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  Future<void> _loadLockers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Filtra solo i locker commerciali
      final lockers = await _lockerRepository.getLockersByType(LockerType.commerciali);
      
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

  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredLockers = _allLockers;
      });
      return;
    }

    final lowerQuery = _searchQuery.toLowerCase();
    setState(() {
      _filteredLockers = _allLockers.where((locker) {
        return locker.name.toLowerCase().contains(lowerQuery) ||
               locker.code.toLowerCase().contains(lowerQuery) ||
               locker.type.label.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _loadRentalCells(String lockerId) async {
    setState(() {
      _isLoadingCells = true;
    });
    
    try {
      // Mostra tutte le celle del locker commerciale
      final allCells = await _lockerRepository.getLockerCells(lockerId);
      
      setState(() {
        _rentalCells = allCells;
        _isLoadingCells = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCells = false;
      });
    }
  }

  void _selectLocker(Locker locker) {
    setState(() {
      _selectedLocker = locker;
    });
    _loadRentalCells(locker.id);
  }

  void _goBack() {
    setState(() {
      _selectedLocker = null;
      _rentalCells = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.isDarkMode;
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          _selectedLocker == null ? 'Affitto Celle' : 'Celle per Affitto',
          style: TextStyle(
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
          ),
        ),
        leading: _selectedLocker != null
            ? CupertinoNavigationBarBackButton(
                color: CupertinoColors.black,
                onPressed: _goBack,
              )
            : null,
      ),
      child: SafeArea(
        child: _selectedLocker == null ? _buildLockerList(isDark) : _buildCellsList(isDark),
      ),
    );
  }

  Widget _buildLockerList(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }

    if (_filteredLockers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.lock_circle,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Nessun locker con celle per affitto'
                  : 'Nessun locker trovato',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Barra di ricerca
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
            border: Border(
              bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
            ),
          ),
          child: CupertinoSearchTextField(
            controller: _searchController,
            placeholder: 'Cerca locker per nome, codice o categoria...',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark 
                  ? CupertinoColors.darkBackgroundGray 
                  : CupertinoColors.white,
              border: Border.all(color: CupertinoColors.separator),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        // Lista locker
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredLockers.length,
            itemBuilder: (context, index) {
              final locker = _filteredLockers[index];
              return _buildLockerItem(locker, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLockerItem(Locker locker, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.all(16),
        onPressed: () => _selectLocker(locker),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CupertinoIcons.lock_circle_fill,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locker.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Codice: ${locker.code}',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locker.type.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: locker.isOnline
                        ? CupertinoColors.systemGreen.withOpacity(0.2)
                        : CupertinoColors.systemRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    locker.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: locker.isOnline
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemRed,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: CupertinoColors.systemGrey,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCellsList(bool isDark) {
    if (_isLoadingCells) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }

    if (_rentalCells.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.lock_circle,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'Nessuna cella per affitto disponibile',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header con info locker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
            border: Border(
              bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.lock_circle_fill,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLocker!.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? CupertinoColors.white : CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Codice: ${_selectedLocker!.code}',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Lista celle
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _rentalCells.length,
            itemBuilder: (context, index) {
              final cell = _rentalCells[index];
              return _buildCellItem(cell, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCellItem(LockerCell cell, bool isDark) {
    final isRented = !cell.isAvailable || _rentalInfo.containsKey(cell.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !isRented
                        ? CupertinoColors.systemGreen.withOpacity(0.2)
                        : CupertinoColors.systemRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    !isRented
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.xmark_circle,
                    color: !isRented
                        ? CupertinoColors.systemGreen
                        : CupertinoColors.systemRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cell.cellNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cell.size.label,
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cell.pricePerHour.toStringAsFixed(2)}€/h • ${cell.pricePerDay.toStringAsFixed(2)}€/giorno',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isRented && _rentalInfo.containsKey(cell.id)) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? CupertinoColors.darkBackgroundGray.withOpacity(0.5)
                                : CupertinoColors.systemGrey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: CupertinoColors.separator,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Azienda: ${_rentalInfo[cell.id]!['companyName'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'P.IVA/CF: ${_rentalInfo[cell.id]!['taxCode'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: !isRented
                            ? CupertinoColors.systemGreen.withOpacity(0.2)
                            : CupertinoColors.systemRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        !isRented ? 'Disponibile' : 'Occupata',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: !isRented
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.systemRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Pulsante Affitta o Termina affitto
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minSize: 0,
                      color: !isRented ? AppColors.primary : CupertinoColors.systemRed,
                      onPressed: () {
                        if (!isRented) {
                          _showRentDialog(cell, isDark);
                        } else {
                          _showTerminateRentDialog(cell, isDark);
                        }
                      },
                      child: Text(
                        !isRented ? 'Affitta' : 'Termina affitto',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRentDialog(LockerCell cell, bool isDark) {
    final companyNameController = TextEditingController();
    final taxCodeController = TextEditingController();
    bool companyNameError = false;
    bool taxCodeError = false;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
            return CupertinoAlertDialog(
            title: const Text('Affitta Cella'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.5,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nome azienda *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: companyNameController,
                        placeholder: 'Inserisci il nome dell\'azienda',
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? CupertinoColors.darkBackgroundGray 
                              : CupertinoColors.white,
                          border: Border.all(
                            color: companyNameError 
                                ? CupertinoColors.systemRed 
                                : CupertinoColors.separator,
                            width: companyNameError ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            companyNameError = value.trim().isEmpty;
                          });
                        },
                      ),
                      if (companyNameError) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Questo campo è obbligatorio',
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.systemRed,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partita IVA / Codice Fiscale *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: taxCodeController,
                        placeholder: 'Inserisci Partita IVA o Codice Fiscale',
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? CupertinoColors.darkBackgroundGray 
                              : CupertinoColors.white,
                          border: Border.all(
                            color: taxCodeError 
                                ? CupertinoColors.systemRed 
                                : CupertinoColors.separator,
                            width: taxCodeError ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            taxCodeError = value.trim().isEmpty;
                          });
                        },
                      ),
                      if (taxCodeError) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Questo campo è obbligatorio',
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.systemRed,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  companyNameController.dispose();
                  taxCodeController.dispose();
                  Navigator.of(context).pop();
                },
                child: const Text('Annulla'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  final companyName = companyNameController.text.trim();
                  final taxCode = taxCodeController.text.trim();
                  
                  setDialogState(() {
                    companyNameError = companyName.isEmpty;
                    taxCodeError = taxCode.isEmpty;
                  });
                  
                  if (companyName.isEmpty || taxCode.isEmpty) {
                    return;
                  }
                  
                  // Chiudi il dialog di input
                  Navigator.of(context).pop();
                  
                  // Aggiorna lo stato
                  setState(() {
                    _rentalInfo[cell.id] = {
                      'companyName': companyName,
                      'taxCode': taxCode,
                    };
                    // Aggiorna la cella nella lista per renderla occupata
                    final index = _rentalCells.indexWhere((c) => c.id == cell.id);
                    if (index != -1) {
                      _rentalCells[index] = _rentalCells[index].copyWith(isAvailable: false);
                    }
                  });
                  
                  companyNameController.dispose();
                  taxCodeController.dispose();
                  
                  // Mostra conferma
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('Affitto confermato'),
                      content: Text('La cella ${cell.cellNumber} è stata affittata a $companyName'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('OK'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Affitta'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTerminateRentDialog(LockerCell cell, bool isDark) {
    final companyName = _rentalInfo[cell.id]?['companyName'] ?? 'N/A';
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Termina affitto'),
        content: Text('Sei sicuro di voler terminare l\'affitto della cella ${cell.cellNumber} per l\'azienda $companyName?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Termina l'affitto
              setState(() {
                _rentalInfo.remove(cell.id);
                // Aggiorna la cella nella lista per renderla disponibile
                final index = _rentalCells.indexWhere((c) => c.id == cell.id);
                if (index != -1) {
                  _rentalCells[index] = _rentalCells[index].copyWith(isAvailable: true);
                }
              });
              
              // Mostra conferma
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Affitto terminato'),
                  content: Text('L\'affitto della cella ${cell.cellNumber} è stato terminato'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Termina'),
          ),
        ],
      ),
    );
  }
}

