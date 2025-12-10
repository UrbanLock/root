import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/features/donations/domain/models/donation.dart';
import 'package:console/features/donations/data/mock_donations.dart';
import 'package:console/features/lockers/data/mock_lockers.dart';
import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/features/lockers/domain/models/locker.dart';
import 'package:console/features/lockers/domain/models/locker_cell.dart';
import 'package:console/features/lockers/domain/repositories/locker_repository.dart';
import 'package:console/features/lockers/data/repositories/locker_repository_mock.dart';
import 'package:console/donation_detail_page.dart';

class DonationsPage extends StatefulWidget {
  final ThemeManager themeManager;
  
  const DonationsPage({super.key, required this.themeManager});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  final TextEditingController _searchController = TextEditingController();
  final LockerRepository _lockerRepository = LockerRepositoryMock();
  
  List<Donation> _allDonations = [];
  List<Donation> _filteredDonations = [];
  String _searchQuery = '';
  DonationStatus? _selectedStatusFilter;
  DonationCategory? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _loadDonations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadDonations() {
    setState(() {
      _allDonations = mockDonations;
      _filteredDonations = mockDonations;
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Donation> filtered = _allDonations;

    // Applica filtro ricerca
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((donation) {
        if (donation.id.toLowerCase().contains(query)) return true;
        if (donation.donorName.toLowerCase().contains(query)) return true;
        if (donation.itemName.toLowerCase().contains(query)) return true;
        if (donation.itemDescription.toLowerCase().contains(query)) return true;
        if (donation.category.label.toLowerCase().contains(query)) return true;
        return false;
      }).toList();
    }

    // Applica filtro stato
    if (_selectedStatusFilter != null) {
      filtered = filtered.where((donation) => donation.status == _selectedStatusFilter).toList();
    }

    // Applica filtro categoria
    if (_selectedCategoryFilter != null) {
      filtered = filtered.where((donation) => donation.category == _selectedCategoryFilter).toList();
    }

    setState(() {
      _filteredDonations = filtered;
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
          ...DonationStatus.values.map((status) => CupertinoActionSheetAction(
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
          ...DonationCategory.values.map((category) => CupertinoActionSheetAction(
            child: Text(category.label),
            onPressed: () {
              setState(() {
                _selectedCategoryFilter = category;
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

  void _changeDonationStatus(Donation donation) {
    if (donation.status == DonationStatus.daVisionare) {
      // Passa a "in valutazione"
      _updateDonationStatus(donation, DonationStatus.inValutazione);
    } else if (donation.status == DonationStatus.inValutazione) {
      // Mostra dialog per accettare o rifiutare
      _showAcceptRejectDialog(donation);
    }
  }

  void _showAcceptRejectDialog(Donation donation) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Gestisci donazione'),
        content: const Text('Vuoi accettare o rifiutare questa donazione?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _updateDonationStatus(donation, DonationStatus.rifiutata);
            },
            child: const Text('Rifiuta'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showPickupLocationDialog(donation);
            },
            child: const Text('Accetta'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
  }

  void _showPickupLocationDialog(Donation donation) {
    String? selectedLocation; // 'comune' o 'cella'
    final isDark = widget.themeManager.isDarkMode;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: const Text('Scegli punto di ritiro'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setDialogState(() {
                      selectedLocation = 'comune';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedLocation == 'comune'
                          ? AppColors.primary.withOpacity(0.2)
                          : (isDark 
                              ? CupertinoColors.darkBackgroundGray 
                              : CupertinoColors.white),
                      border: Border.all(
                        color: selectedLocation == 'comune'
                            ? AppColors.primary
                            : CupertinoColors.separator,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedLocation == 'comune'
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          color: selectedLocation == 'comune'
                              ? AppColors.primary
                              : CupertinoColors.systemGrey,
                        ),
                        const SizedBox(width: 12),
                        const Text('Ritiro al comune'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setDialogState(() {
                      selectedLocation = 'cella';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedLocation == 'cella'
                          ? AppColors.primary.withOpacity(0.2)
                          : (isDark 
                              ? CupertinoColors.darkBackgroundGray 
                              : CupertinoColors.white),
                      border: Border.all(
                        color: selectedLocation == 'cella'
                            ? AppColors.primary
                            : CupertinoColors.separator,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedLocation == 'cella'
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          color: selectedLocation == 'cella'
                              ? AppColors.primary
                              : CupertinoColors.systemGrey,
                        ),
                        const SizedBox(width: 12),
                        const Text('Ritiro in cella'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annulla'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  if (selectedLocation == null) return;
                  
                  Navigator.of(context).pop();
                  
                  if (selectedLocation == 'comune') {
                    _updateDonationStatus(
                      donation,
                      DonationStatus.accettata,
                      isComunePickup: true,
                    );
                  } else {
                    _showLockerSelectionDialog(donation);
                  }
                },
                child: Text(
                  'Conferma',
                  style: TextStyle(
                    color: selectedLocation != null
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

  void _showLockerSelectionDialog(Donation donation) async {
    // Mappa categoria donazione a tipo locker
    LockerType? lockerType;
    switch (donation.category) {
      case DonationCategory.sportivi:
        lockerType = LockerType.sportivi;
        break;
      case DonationCategory.personali:
        lockerType = LockerType.personali;
        break;
      case DonationCategory.petFriendly:
        lockerType = LockerType.petFriendly;
        break;
      case DonationCategory.commerciali:
        lockerType = LockerType.commerciali;
        break;
      case DonationCategory.cicloturistici:
        lockerType = LockerType.cicloturistici;
        break;
    }

    if (lockerType == null) return;

    // Carica i locker per questa categoria
    final lockers = await _lockerRepository.getLockersByType(lockerType);
    
    if (lockers.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Nessun locker disponibile'),
          content: Text('Non ci sono locker disponibili per la categoria ${donation.category.label}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    Locker? selectedLocker;
    final isDark = widget.themeManager.isDarkMode;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: const Text('Seleziona locker'),
            content: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: lockers.map((locker) {
                    final isSelected = selectedLocker?.id == locker.id;
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setDialogState(() {
                          selectedLocker = locker;
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
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color: isSelected
                                  ? AppColors.primary
                                  : CupertinoColors.systemGrey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    locker.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark 
                                          ? CupertinoColors.white 
                                          : CupertinoColors.black,
                                    ),
                                  ),
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
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
                  if (selectedLocker == null) return;
                  Navigator.of(context).pop();
                  _showCellSelectionDialog(donation, selectedLocker!);
                },
                child: Text(
                  'Avanti',
                  style: TextStyle(
                    color: selectedLocker != null
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

  void _showCellSelectionDialog(Donation donation, Locker locker) async {
    final cells = await _lockerRepository.getLockerCells(locker.id);
    final availableCells = cells.where((cell) => cell.isAvailable).toList();
    
    if (availableCells.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Nessuna cella disponibile'),
          content: Text('Non ci sono celle disponibili nel locker ${locker.name}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    LockerCell? selectedCell;
    final isDark = widget.themeManager.isDarkMode;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: Text('Seleziona cella - ${locker.name}'),
            content: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: availableCells.map((cell) {
                    final isSelected = selectedCell?.id == cell.id;
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setDialogState(() {
                          selectedCell = cell;
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
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color: isSelected
                                  ? AppColors.primary
                                  : CupertinoColors.systemGrey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cell.cellNumber,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark 
                                          ? CupertinoColors.white 
                                          : CupertinoColors.black,
                                    ),
                                  ),
                                  Text(
                                    cell.size.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
                  if (selectedCell == null) return;
                  Navigator.of(context).pop();
                  _updateDonationStatus(
                    donation,
                    DonationStatus.accettata,
                    lockerId: locker.id,
                    cellId: selectedCell!.id,
                    isComunePickup: false,
                  );
                },
                child: Text(
                  'Conferma',
                  style: TextStyle(
                    color: selectedCell != null
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

  void _updateDonationStatus(
    Donation donation,
    DonationStatus newStatus, {
    String? lockerId,
    String? cellId,
    bool? isComunePickup,
  }) {
    setState(() {
      final index = _allDonations.indexWhere((d) => d.id == donation.id);
      if (index != -1) {
        _allDonations[index] = donation.copyWith(
          status: newStatus,
          lockerId: lockerId,
          cellId: cellId,
          isComunePickup: isComunePickup,
        );
        _applyFilters();
      }
    });
  }

  Color _getStatusColor(DonationStatus status) {
    switch (status) {
      case DonationStatus.daVisionare:
        return CupertinoColors.systemOrange;
      case DonationStatus.inValutazione:
        return CupertinoColors.systemBlue;
      case DonationStatus.accettata:
        return CupertinoColors.systemGreen;
      case DonationStatus.rifiutata:
        return CupertinoColors.systemRed;
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
        middle: const Text('Donazioni'),
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
            
            // Lista donazioni
            Expanded(
              child: _filteredDonations.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty || _selectedStatusFilter != null || _selectedCategoryFilter != null
                            ? 'Nessuna donazione trovata'
                            : 'Nessuna donazione disponibile',
                        style: TextStyle(
                          color: isDark 
                              ? CupertinoColors.white 
                              : CupertinoColors.black,
                        ),
                      ),
                    )
                  : _buildDonationsList(isDark),
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
                  placeholder: 'Cerca per donatore, oggetto, categoria...',
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
                            _selectedCategoryFilter?.label ?? 'Categoria',
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

  Widget _buildDonationsList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDonations.length,
      itemBuilder: (context, index) {
        final donation = _filteredDonations[index];
        return _buildDonationItem(donation, isDark);
      },
    );
  }

  Widget _buildDonationItem(Donation donation, bool isDark) {
    final statusColor = _getStatusColor(donation.status);
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => DonationDetailPage(
              donation: donation,
              themeManager: widget.themeManager,
            ),
          ),
        );
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
                        'Donazione ${donation.id.toUpperCase()}',
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
                            CupertinoIcons.person,
                            size: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            donation.donorName,
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
                        donation.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (donation.status != DonationStatus.accettata && 
                        donation.status != DonationStatus.rifiutata) ...[
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () => _changeDonationStatus(donation),
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
                  donation.category.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  CupertinoIcons.cube,
                  size: 14,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  donation.itemName,
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              donation.itemDescription,
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
                  '${donation.createdAt.day}/${donation.createdAt.month}/${donation.createdAt.year} ${donation.createdAt.hour}:${donation.createdAt.minute.toString().padLeft(2, '0')}',
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

