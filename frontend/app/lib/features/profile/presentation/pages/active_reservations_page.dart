import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Per Divider
import 'package:image_picker/image_picker.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/profile/presentation/pages/open_cell_page.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';

class ActiveReservationsPage extends StatefulWidget {
  final ThemeManager themeManager;

  const ActiveReservationsPage({
    super.key,
    required this.themeManager,
  });

  @override
  State<ActiveReservationsPage> createState() => _ActiveReservationsPageState();
}

class _ActiveReservationsPageState extends State<ActiveReservationsPage> {
  final ImagePicker _imagePicker = ImagePicker();
  
  // Mock: lista celle attive
  // TODO: Quando il backend sarà pronto, caricare da CellRepository
  final List<ActiveCell> _activeCells = [
    ActiveCell(
      id: '1',
      lockerId: 'locker_1',
      lockerName: 'Parco delle Albere',
      lockerType: 'Sportivi',
      cellNumber: 'Cella 3',
      cellId: 'cell_1',
      startTime: DateTime.now().subtract(const Duration(hours: 2)),
      endTime: DateTime.now().add(const Duration(hours: 2, minutes: 15)),
      type: CellUsageType.deposited,
    ),
    ActiveCell(
      id: '2',
      lockerId: 'locker_2',
      lockerName: 'Centro Storico',
      lockerType: 'Personali',
      cellNumber: 'Cella 7',
      cellId: 'cell_2',
      startTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      endTime: DateTime.now().add(const Duration(hours: 5, minutes: 30)),
      type: CellUsageType.borrowed,
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _openCell(ActiveCell cell) async {
    // Per le celle in prestito, quando si rimette l'oggetto serve la foto
    // Per le celle depositate, non serve foto
    // Per le celle pickup, non serve foto
    if (cell.type == CellUsageType.borrowed) {
      // Quando si rimette un oggetto in prestito, serve la foto
      final shouldTakePhoto = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Rimetti oggetto'),
          content: const Text(
            'Per rimettere l\'oggetto nella cella è necessario scattare una foto dell\'oggetto.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Annulla'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Scatta foto'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (shouldTakePhoto != true) return;

      try {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (image == null) {
          if (mounted) {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Foto richiesta'),
                content: const Text(
                  'È necessario scattare una foto dell\'oggetto per poter rimettere l\'oggetto nella cella.',
                ),
                actions: [
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: const Text('OK'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          }
          return;
        }

        _confirmOpenCell(cell, File(image.path));
      } catch (e) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Errore'),
              content: Text('Impossibile scattare la foto: $e'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
      }
    } else {
      // Per deposit e pickup, non serve foto
      _confirmOpenCell(cell, null);
    }
  }

  void _confirmOpenCell(ActiveCell cell, File? photo) {
    // Naviga alla pagina di rilevamento Bluetooth
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => OpenCellPage(
          themeManager: widget.themeManager,
          cell: cell,
          photo: photo,
          onCellClosed: (cellId) {
            // Rimuovi la cella dalla lista quando lo sportello viene chiuso
            _removeCell(cellId);
          },
        ),
      ),
    );
  }

  // Metodo per rimuovere una cella dalla lista (chiamato quando lo sportello viene chiuso)
  void _removeCell(String cellId) {
    setState(() {
      _activeCells.removeWhere((c) => c.id == cellId);
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
              'Celle attive',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: _activeCells.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.lock,
                            size: 64,
                            color: AppColors.textSecondary(isDark).withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Nessuna cella attiva',
                            style: AppTextStyles.title(isDark).copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Le tue celle attive appariranno qui',
                            style: AppTextStyles.bodySecondary(isDark),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    children: [
                      // Header minimal
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Le tue celle',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(isDark),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      // Lista celle attive
                      ..._activeCells.map((cell) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildReservationCard(
                            context: context,
                            isDark: isDark,
                            reservation: cell,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildReservationCard({
    required BuildContext context,
    required bool isDark,
    required ActiveCell reservation,
  }) {
    final isBorrowed = reservation.type == CellUsageType.borrowed;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icona minimal
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (isBorrowed
                            ? CupertinoColors.systemOrange
                            : CupertinoColors.systemGreen)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isBorrowed
                        ? CupertinoIcons.arrow_down_circle
                        : CupertinoIcons.arrow_up_circle,
                    size: 20,
                    color: isBorrowed
                        ? CupertinoColors.systemOrange
                        : CupertinoColors.systemGreen,
                  ),
                ),
                const SizedBox(width: 12),
                // Info principale
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation.lockerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reservation.cellNumber,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge minimal
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isBorrowed
                            ? CupertinoColors.systemOrange
                            : CupertinoColors.systemGreen)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBorrowed ? 'In prestito' : 'Depositato',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isBorrowed
                          ? CupertinoColors.systemOrange
                          : CupertinoColors.systemGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Divider sottile
          Divider(
            height: 1,
            color: AppColors.borderColor(isDark).withOpacity(0.1),
          ),
          // Info secondarie
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    isDark: isDark,
                    label: 'Inizio',
                    value: reservation.formattedStartTime,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppColors.borderColor(isDark).withOpacity(0.2),
                ),
                Expanded(
                  child: _buildInfoItem(
                    isDark: isDark,
                    label: 'Scade',
                    value: reservation.formattedEndTime ?? 'Nessuna scadenza',
                  ),
                ),
              ],
            ),
          ),
          // Divider sottile
          Divider(
            height: 1,
            color: AppColors.borderColor(isDark).withOpacity(0.1),
          ),
          // Pulsante apri
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _openCell(reservation),
                child: Text(
                  isBorrowed ? 'Apri per rimettere' : 'Apri per prelevare',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required bool isDark,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(isDark).withOpacity(0.7),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.text(isDark),
          ),
        ),
      ],
    );
  }
}
