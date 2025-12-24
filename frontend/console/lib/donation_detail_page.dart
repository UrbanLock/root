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
import 'package:console/features/lockers/data/repositories/locker_repository_api.dart';

class DonationDetailPage extends StatefulWidget {
  final Donation donation;
  final ThemeManager themeManager;
  
  const DonationDetailPage({
    super.key,
    required this.donation,
    required this.themeManager,
  });

  @override
  State<DonationDetailPage> createState() => _DonationDetailPageState();
}

class _DonationDetailPageState extends State<DonationDetailPage> {
  late Donation _currentDonation;
  final LockerRepository _lockerRepository = LockerRepositoryApi();

  @override
  void initState() {
    super.initState();
    _currentDonation = widget.donation;
  }

  void _changeDonationStatus() {
    if (_currentDonation.status == DonationStatus.daVisionare) {
      // Passa a "in valutazione"
      _updateDonationStatus(DonationStatus.inValutazione);
    } else if (_currentDonation.status == DonationStatus.inValutazione) {
      // Mostra dialog per accettare o rifiutare
      _showAcceptRejectDialog();
    }
  }

  void _updateDonationStatus(
    DonationStatus newStatus, {
    String? lockerId,
    String? cellId,
    bool? isComunePickup,
  }) {
    setState(() {
      final index = mockDonations.indexWhere((d) => d.id == _currentDonation.id);
      if (index != -1) {
        _currentDonation = _currentDonation.copyWith(
          status: newStatus,
          lockerId: lockerId,
          cellId: cellId,
          isComunePickup: isComunePickup,
        );
        mockDonations[index] = _currentDonation;
      }
    });
  }

  void _showAcceptRejectDialog() {
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
              _updateDonationStatus(DonationStatus.rifiutata);
            },
            child: const Text('Rifiuta'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showPickupLocationDialog();
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

  void _showPickupLocationDialog() {
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
                      DonationStatus.accettata,
                      isComunePickup: true,
                    );
                  } else {
                    _showLockerSelectionDialog();
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

  void _showLockerSelectionDialog() async {
    // Mappa categoria donazione a tipo locker
    LockerType? lockerType;
    switch (_currentDonation.category) {
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
          content: Text('Non ci sono locker disponibili per la categoria ${_currentDonation.category.label}'),
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
                  _showCellSelectionDialog(selectedLocker!);
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

  void _showCellSelectionDialog(Locker locker) async {
    final cells = await _lockerRepository.getLockerCells(locker.id);
    
    if (cells.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Nessuna cella disponibile'),
          content: Text('Non ci sono celle nel locker ${locker.name}'),
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
    List<LockerCell> cellsList = List.from(cells);
    final isDark = widget.themeManager.isDarkMode;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: Text('Seleziona cella - ${locker.name}'),
            content: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: cellsList.map((cell) {
                    final isSelected = selectedCell?.id == cell.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
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
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: () {
                              setDialogState(() {
                                if (cell.isAvailable) {
                                  selectedCell = cell;
                                }
                              });
                            },
                            child: Icon(
                              isSelected && cell.isAvailable
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color: isSelected && cell.isAvailable
                                  ? AppColors.primary
                                  : CupertinoColors.systemGrey,
                            ),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cell.isAvailable
                                  ? CupertinoColors.systemGreen.withOpacity(0.2)
                                  : (cell.stato == 'manutenzione'
                                      ? CupertinoColors.systemOrange.withOpacity(0.2)
                                      : CupertinoColors.systemRed.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              cell.isAvailable 
                                  ? 'Disponibile' 
                                  : (cell.stato == 'manutenzione' ? 'In manutenzione' : 'Occupata'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cell.isAvailable
                                    ? CupertinoColors.systemGreen
                                    : (cell.stato == 'manutenzione' 
                                        ? CupertinoColors.systemOrange 
                                        : CupertinoColors.systemRed),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: () => _toggleCellStatusInDialog(cell, locker, setDialogState, cellsList),
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
                  if (selectedCell == null || !selectedCell!.isAvailable) return;
                  Navigator.of(context).pop();
                  _updateDonationStatus(
                    DonationStatus.accettata,
                    lockerId: locker.id,
                    cellId: selectedCell!.id,
                    isComunePickup: false,
                  );
                },
                child: Text(
                  'Conferma',
                  style: TextStyle(
                    color: selectedCell != null && selectedCell!.isAvailable
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

  Future<void> _toggleCellStatusInDialog(
    LockerCell cell,
    Locker locker,
    StateSetter setDialogState,
    List<LockerCell> cellsList,
  ) async {
    final newStatus = !cell.isAvailable;
    final statoBackend = newStatus ? 'libera' : 'manutenzione';
    
    try {
      final success = await _lockerRepository.updateCellStatus(cell.id, statoBackend);
      if (success) {
        setDialogState(() {
          final index = cellsList.indexWhere((c) => c.id == cell.id);
          if (index != -1) {
            cellsList[index] = LockerCell(
              id: cell.id,
              cellNumber: cell.cellNumber,
              type: cell.type,
              size: cell.size,
              isAvailable: newStatus,
              stato: newStatus ? 'libera' : 'manutenzione',
              pricePerHour: cell.pricePerHour,
              pricePerDay: cell.pricePerDay,
              itemName: cell.itemName,
              itemDescription: cell.itemDescription,
              itemImageUrl: cell.itemImageUrl,
              storeName: cell.storeName,
              availableUntil: cell.availableUntil,
              borrowDuration: cell.borrowDuration,
            );
          }
        });
      } else {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Errore'),
              content: const Text('Impossibile aggiornare lo stato della cella. Riprova più tardi.'),
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

  String _getLocationInfo() {
    if (_currentDonation.isComunePickup) {
      return 'Ritiro al comune';
    }
    
    if (_currentDonation.lockerId != null) {
      final locker = mockLockers.firstWhere(
        (l) => l.id == _currentDonation.lockerId,
        orElse: () => mockLockers.first,
      );
      
      if (_currentDonation.cellId != null) {
        return '${locker.name} (${locker.code}) - Cella ${_currentDonation.cellId}';
      }
      
      return '${locker.name} (${locker.code})';
    }
    
    return 'Non specificato';
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
    final statusColor = _getStatusColor(_currentDonation.status);
    
    return CupertinoPageScaffold(
      backgroundColor: isDark 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        middle: Text(
          'Donazione ${_currentDonation.id.toUpperCase()}',
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
              // ID Donazione
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
                      CupertinoIcons.gift,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID Donazione',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDonation.id.toUpperCase(),
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
                            _currentDonation.status.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (_currentDonation.status != DonationStatus.accettata && 
                            _currentDonation.status != DonationStatus.rifiutata) ...[
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: _changeDonationStatus,
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
              
              // Donatore
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
                      CupertinoIcons.person,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Donatore',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDonation.donorName,
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
              
              // Categoria
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
                            'Categoria',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDonation.category.label,
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
              
              // Nome oggetto
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
                      CupertinoIcons.cube,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nome oggetto',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDonation.itemName,
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
                      _currentDonation.itemDescription,
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
              if (_currentDonation.photoUrl != null) ...[
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
                          _currentDonation.photoUrl!,
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
                              child: const Center(
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
              
              // Punto di ritiro (se accettata)
              if (_currentDonation.status == DonationStatus.accettata) ...[
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
                              'Punto di ritiro',
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getLocationInfo(),
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
                            '${_currentDonation.createdAt.day}/${_currentDonation.createdAt.month}/${_currentDonation.createdAt.year} ${_currentDonation.createdAt.hour}:${_currentDonation.createdAt.minute.toString().padLeft(2, '0')}',
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

