import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/cell_type.dart';
import 'package:app/features/profile/presentation/pages/open_cell_page.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';

/// Pagina di dettaglio di un locker
/// 
/// Mostra informazioni dettagliate sul locker e permette di:
/// - Prendere in prestito oggetti dalle celle disponibili
/// - Depositare oggetti personali (a pagamento)
/// - Ritirare prodotti da negozi locali
/// 
/// **TODO quando il backend sarà pronto:**
/// - Caricare informazioni dettagliate dal backend (GET /api/v1/lockers/:id)
/// - Mostrare celle disponibili in tempo reale
/// - Implementare prenotazione/pagamento tramite backend
class LockerDetailPage extends StatefulWidget {
  final ThemeManager themeManager;
  final Locker locker;
  final CellRepository? cellRepository;

  const LockerDetailPage({
    super.key,
    required this.themeManager,
    required this.locker,
    this.cellRepository,
  });

  @override
  State<LockerDetailPage> createState() => _LockerDetailPageState();
}

class _LockerDetailPageState extends State<LockerDetailPage> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true;
  List<LockerCell> _cells = [];
  LockerCellStats? _cellStats;

  @override
  void initState() {
    super.initState();
    _loadCells();
  }

  Future<void> _loadCells() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Quando il backend sarà pronto, caricare celle dal repository
      final repository = AppDependencies.lockerRepository;
      _cells = await repository.getLockerCells(widget.locker.id);
      _cellStats = await repository.getLockerCellStats(widget.locker.id);
    } catch (e) {
      // Gestisci errore
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Gestisce la selezione di una cella per il prestito
  /// 
  /// **Flusso:**
  /// 1. L'utente apre la cella
  /// 2. Chiude la cella (preleva l'oggetto)
  /// 3. Ha un tempo determinato per utilizzare l'oggetto
  /// 4. Quando rimette l'oggetto, deve scattare una foto
  Future<void> _handleBorrowCell(LockerCell cell) async {
    final borrowDuration = cell.borrowDuration ?? const Duration(days: 7);
    final durationText = borrowDuration.inDays > 0
        ? '${borrowDuration.inDays} giorni'
        : '${borrowDuration.inHours} ore';

    final shouldBorrow = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Prendi in prestito: ${cell.itemName ?? "Oggetto"}'),
        content: Text(
          '${cell.itemDescription ?? ""}\n\nTempo di prestito: $durationText\n\nQuando rimetti l\'oggetto, sarà richiesta una foto.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Prendi in prestito'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldBorrow != true) return;

    // TODO: Quando il backend sarà pronto, chiamare API per prendere in prestito
    // final activeCell = await widget.cellRepository!.borrowCell(cell.id);

    // Crea una cella attiva mock
    final activeCell = ActiveCell(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lockerId: widget.locker.id,
      lockerName: widget.locker.name,
      lockerType: widget.locker.type.label,
      cellNumber: cell.cellNumber,
      cellId: cell.id,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(borrowDuration),
      type: CellUsageType.borrowed,
    );

    if (mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => OpenCellPage(
            themeManager: widget.themeManager,
            cell: activeCell,
            // Nessuna foto all'apertura, ma sarà richiesta quando rimette l'oggetto
            onCellClosed: (cellId) {},
          ),
        ),
      );
    }
  }

  /// Gestisce la richiesta di una cella per depositare
  /// 
  /// **NOTA**: Per depositare NON è richiesta la foto
  Future<void> _handleDepositCell(LockerCell cell) async {
    // Mostra informazioni sul prezzo e dimensione
    final priceInfo = '€${cell.pricePerDay.toStringAsFixed(2)}/giorno o €${cell.pricePerHour.toStringAsFixed(2)}/ora';
    final sizeInfo = '${cell.size.label} (${cell.size.dimensions})';

    final shouldDeposit = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Deposita oggetto'),
        content: Text(
          'Dimensione: $sizeInfo\nCosto: $priceInfo\n\nLa cella sarà disponibile per 24 ore.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Conferma'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldDeposit != true) return;

    // TODO: Quando il backend sarà pronto, chiamare API per depositare
    // final activeCell = await widget.cellRepository!.requestCell(
    //   widget.locker.id,
    //   cellId: cell.id,
    // );

    // Crea una cella attiva mock (senza foto)
    final activeCell = ActiveCell(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lockerId: widget.locker.id,
      lockerName: widget.locker.name,
      lockerType: widget.locker.type.label,
      cellNumber: cell.cellNumber,
      cellId: cell.id,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 24)),
      type: CellUsageType.deposited,
    );

    if (mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => OpenCellPage(
            themeManager: widget.themeManager,
            cell: activeCell,
            // Nessuna foto richiesta per depositare
            onCellClosed: (cellId) {},
          ),
        ),
      );
    }
  }

  /// Gestisce il ritiro di un prodotto
  Future<void> _handlePickupCell(LockerCell cell) async {
    final timeRemaining = cell.availableUntil != null
        ? cell.availableUntil!.difference(DateTime.now())
        : null;

    final timeInfo = timeRemaining != null && timeRemaining.inHours > 0
        ? 'Disponibile per altre ${timeRemaining.inHours} ore'
        : timeRemaining != null && timeRemaining.inMinutes > 0
            ? 'Disponibile per altri ${timeRemaining.inMinutes} minuti'
            : 'Disponibile';

    final shouldPickup = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Ritira: ${cell.itemName ?? "Prodotto"}'),
        content: Text(
          'Negoziante: ${cell.storeName ?? "N/A"}\n$timeInfo\n\nVuoi ritirare questo prodotto?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Ritira'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldPickup != true) return;

    // TODO: Quando il backend sarà pronto, chiamare API per ritirare
    // final activeCell = await widget.cellRepository!.pickupCell(cell.id);

    // Crea una cella attiva mock (tipo deposited perché l'utente "deposita" il prodotto ritirato)
    final activeCell = ActiveCell(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lockerId: widget.locker.id,
      lockerName: widget.locker.name,
      lockerType: widget.locker.type.label,
      cellNumber: cell.cellNumber,
      cellId: cell.id,
      startTime: DateTime.now(),
      endTime: null, // Nessuna scadenza per prodotti ritirati
      type: CellUsageType.deposited,
    );

    if (mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => OpenCellPage(
            themeManager: widget.themeManager,
            cell: activeCell,
            onCellClosed: (cellId) {},
          ),
        ),
      );
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
              widget.locker.name,
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Icona locker
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.iconBackground(isDark),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            widget.locker.type.icon,
                            size: 40,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Nome e tipo
                      Text(
                        widget.locker.name,
                        style: AppTextStyles.title(isDark).copyWith(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.locker.type.label,
                        style: AppTextStyles.bodySecondary(isDark),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.locker.description != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          widget.locker.description!,
                          style: AppTextStyles.body(isDark),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 32),
                      // Statistiche celle
                      if (_cellStats != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface(isDark),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Disponibilità',
                                style: AppTextStyles.title(isDark),
                              ),
                              const SizedBox(height: 16),
                              _buildStatRow(
                                isDark: isDark,
                                label: 'Totale',
                                value: '${_cellStats!.totalCells} celle',
                              ),
                              const SizedBox(height: 12),
                              _buildStatRow(
                                isDark: isDark,
                                label: CellType.borrow.label,
                                value: '${_cellStats!.availableBorrowCells} disponibili',
                                icon: CellType.borrow.icon,
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                isDark: isDark,
                                label: CellType.deposit.label,
                                value: '${_cellStats!.availableDepositCells} disponibili',
                                icon: CellType.deposit.icon,
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                isDark: isDark,
                                label: CellType.pickup.label,
                                value: '${_cellStats!.availablePickupCells} disponibili',
                                icon: CellType.pickup.icon,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      // Sezioni per tipo di cella
                      if (_cells.isNotEmpty) ...[
                        // Celle per prendere in prestito
                        if (_cells.any((c) => c.type == CellType.borrow && c.isAvailable))
                          _buildCellTypeSection(
                            isDark: isDark,
                            title: CellType.borrow.label,
                            description: CellType.borrow.description,
                            icon: CellType.borrow.icon,
                            cells: _cells.where((c) => c.type == CellType.borrow && c.isAvailable).toList(),
                            onCellTap: _handleBorrowCell,
                          ),
                        // Celle per depositare
                        if (_cells.any((c) => c.type == CellType.deposit && c.isAvailable))
                          _buildCellTypeSection(
                            isDark: isDark,
                            title: CellType.deposit.label,
                            description: CellType.deposit.description,
                            icon: CellType.deposit.icon,
                            cells: _cells.where((c) => c.type == CellType.deposit && c.isAvailable).toList(),
                            onCellTap: _handleDepositCell,
                          ),
                        // Celle per ritirare
                        if (_cells.any((c) => c.type == CellType.pickup && c.isAvailable))
                          _buildCellTypeSection(
                            isDark: isDark,
                            title: CellType.pickup.label,
                            description: CellType.pickup.description,
                            icon: CellType.pickup.icon,
                            cells: _cells.where((c) => c.type == CellType.pickup && c.isAvailable).toList(),
                            onCellTap: _handlePickupCell,
                          ),
                      ] else ...[
                        // Nessuna cella disponibile
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  CupertinoIcons.lock,
                                  size: 64,
                                  color: AppColors.textSecondary(isDark),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Nessuna cella disponibile',
                                  style: AppTextStyles.title(isDark),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tutte le celle sono attualmente occupate',
                                  style: AppTextStyles.bodySecondary(isDark),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow({
    required bool isDark,
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySecondary(isDark),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body(isDark).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCellTypeSection({
    required bool isDark,
    required String title,
    required String description,
    required IconData icon,
    required List<LockerCell> cells,
    required Function(LockerCell) onCellTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.iconBackground(isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: AppColors.primary(isDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.title(isDark),
                  ),
                  Text(
                    description,
                    style: AppTextStyles.bodySecondary(isDark).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...cells.map((cell) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildCellCard(
              isDark: isDark,
              cell: cell,
              onTap: () => onCellTap(cell),
            ),
          );
        }).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCellCard({
    required bool isDark,
    required LockerCell cell,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderColor(isDark).withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cell.cellNumber,
                          style: AppTextStyles.body(isDark).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (cell.type == CellType.deposit)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary(isDark).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '€${cell.pricePerDay.toStringAsFixed(2)}/g',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${cell.size.label} (${cell.size.dimensions})',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  if (cell.itemName != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      cell.itemName!,
                      style: AppTextStyles.body(isDark),
                    ),
                  ],
                  if (cell.itemDescription != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      cell.itemDescription!,
                      style: AppTextStyles.bodySecondary(isDark).copyWith(fontSize: 12),
                    ),
                  ],
                  if (cell.storeName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.bag,
                          size: 12,
                          color: AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cell.storeName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (cell.borrowDuration != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 12,
                          color: AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Prestito: ${cell.borrowDuration!.inDays} giorni',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textSecondary(isDark),
            ),
          ],
        ),
      ),
    );
  }
}
