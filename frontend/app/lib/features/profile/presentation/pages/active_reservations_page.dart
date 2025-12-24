import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/profile/presentation/pages/return_cell_page.dart';
import 'package:app/features/payment/presentation/pages/deposit_open_cell_page.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/cell_type.dart';

/// Pagina che mostra le celle attive dell'utente
/// 
/// Mostra 3 categorie di celle:
/// - Celle con oggetti presi in prestito: pulsante "Restituisci"
/// - Celle per deposito di oggetti personali: pulsante "Sblocca cella"
/// - Celle per ordini consegnati da negozi locali: pulsante "Sblocca cella"
/// 
/// **TODO quando il backend sarà pronto:**
/// - Caricare celle attive dal backend (GET /api/v1/cells/active)
/// - Aggiornare in tempo reale quando una cella viene chiusa
/// - Gestire estensione durata per depositi (a pagamento)
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
  List<ActiveCell> _activeCells = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActiveCells();
  }

  /// Carica le celle attive
  /// 
  /// **TODO BACKEND**: Sostituire con chiamata API reale
  /// GET /api/v1/cells/active
  Future<void> _loadActiveCells() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ⚠️ SOLO PER TESTING: Usa repository mock
      // IN PRODUZIONE: Il repository reale farà chiamate HTTP
      final repository = AppDependencies.cellRepository;
      if (repository != null) {
        _activeCells = await repository.getActiveCells();
      } else {
        _activeCells = [];
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

  /// Gestisce il click su "Restituisci" per una cella in prestito
  void _handleReturnBorrowed(ActiveCell cell) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ReturnCellPage(
          themeManager: widget.themeManager,
          cell: cell,
        ),
      ),
    ).then((_) {
      // Ricarica le celle attive dopo la restituzione
      _loadActiveCells();
    });
  }

  /// Gestisce il click su "Sblocca cella" per una cella depositata
  void _handleUnlockDeposited(ActiveCell cell) {
    // Crea una LockerCell mock per la navigazione
    final mockCell = LockerCell(
      id: cell.cellId,
      cellNumber: cell.cellNumber,
      type: CellType.deposit,
      size: CellSize.medium, // Default, in produzione verrà dal backend
      isAvailable: false,
      pricePerHour: 2.0,
      pricePerDay: 10.0,
    );

    // Calcola la durata rimanente
    final remainingDuration = cell.endTime != null
        ? cell.endTime!.difference(DateTime.now())
        : const Duration(days: 1);

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => DepositOpenCellPage(
          themeManager: widget.themeManager,
          cell: mockCell,
          lockerName: cell.lockerName,
          lockerId: cell.lockerId,
          duration: remainingDuration,
          skipBluetoothVerification: false, // Verifica Bluetooth per sbloccare
        ),
      ),
    ).then((_) {
      // Ricarica le celle attive dopo lo sblocco
      _loadActiveCells();
    });
  }

  /// Gestisce il click su "Sblocca cella" per un ordine pickup
  void _handleUnlockPickup(ActiveCell cell) {
    // Crea una LockerCell mock per la navigazione
    final mockCell = LockerCell(
      id: cell.cellId,
      cellNumber: cell.cellNumber,
      type: CellType.pickup,
      size: CellSize.medium, // Default, in produzione verrà dal backend
      isAvailable: false,
      pricePerHour: 0.0,
      pricePerDay: 0.0,
    );

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => DepositOpenCellPage(
          themeManager: widget.themeManager,
          cell: mockCell,
          lockerName: cell.lockerName,
          lockerId: cell.lockerId,
          duration: const Duration(days: 1), // Default per pickup
          skipBluetoothVerification: false, // Verifica Bluetooth per sbloccare
        ),
      ),
    ).then((_) {
      // Ricarica le celle attive dopo lo sblocco
      _loadActiveCells();
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
                                onPressed: _loadActiveCells,
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        ),
                      )
                        : _activeCells.isEmpty
                        ? CustomScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              CupertinoSliverRefreshControl(
                                onRefresh: _loadActiveCells,
                              ),
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
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
                                ),
                              ),
                            ],
                          )
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              CupertinoSliverRefreshControl(
                                onRefresh: _loadActiveCells,
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.all(20),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    // Celle in prestito
                                    if (_activeCells.any((c) => c.type == CellUsageType.borrowed)) ...[
                                      _buildSectionHeader(
                                        isDark: isDark,
                                        title: 'Oggetti in prestito',
                                        icon: CupertinoIcons.arrow_down_circle,
                                      ),
                                      const SizedBox(height: 12),
                                      ..._activeCells
                                          .where((c) => c.type == CellUsageType.borrowed)
                                          .map((cell) => Padding(
                                                padding: const EdgeInsets.only(bottom: 12),
                                                child: _buildBorrowedCellCard(
                                                  isDark: isDark,
                                                  cell: cell,
                                                ),
                                              )),
                                      const SizedBox(height: 24),
                                    ],
                                    // Celle depositate
                                    if (_activeCells.any((c) => c.type == CellUsageType.deposited)) ...[
                                      _buildSectionHeader(
                                        isDark: isDark,
                                        title: 'Depositi attivi',
                                        icon: CupertinoIcons.lock,
                                      ),
                                      const SizedBox(height: 12),
                                      ..._activeCells
                                          .where((c) => c.type == CellUsageType.deposited)
                                          .map((cell) => Padding(
                                                padding: const EdgeInsets.only(bottom: 12),
                                                child: _buildDepositedCellCard(
                                                  isDark: isDark,
                                                  cell: cell,
                                                ),
                                              )),
                                      const SizedBox(height: 24),
                                    ],
                                    // Celle pickup
                                    if (_activeCells.any((c) => c.type == CellUsageType.pickup)) ...[
                                      _buildSectionHeader(
                                        isDark: isDark,
                                        title: 'Ordini da ritirare',
                                        icon: CupertinoIcons.cart_fill,
                                      ),
                                      const SizedBox(height: 12),
                                      ..._activeCells
                                          .where((c) => c.type == CellUsageType.pickup)
                                          .map((cell) => Padding(
                                                padding: const EdgeInsets.only(bottom: 12),
                                                child: _buildPickupCellCard(
                                                  isDark: isDark,
                                                  cell: cell,
                                                ),
                                              )),
                                    ],
                                  ]),
                                ),
                              ),
                            ],
                          ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required bool isDark,
    required String title,
    required IconData icon,
  }) {
    return Row(
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
        Text(
          title,
          style: AppTextStyles.title(isDark),
        ),
      ],
    );
  }

  Widget _buildBorrowedCellCard({
    required bool isDark,
    required ActiveCell cell,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_down_circle,
                      size: 20,
                      color: AppColors.primary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cell.cellNumber,
                      style: AppTextStyles.title(isDark).copyWith(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.location,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cell.lockerName,
                        style: AppTextStyles.body(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Iniziato: ${cell.formattedStartTime}',
                      style: AppTextStyles.bodySecondary(isDark),
                    ),
                  ],
                ),
                if (cell.formattedEndTime != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 16,
                        color: AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cell.formattedEndTime!,
                        style: AppTextStyles.bodySecondary(isDark),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _handleReturnBorrowed(cell),
                child: const Text(
                  'Restituisci',
                  style: TextStyle(
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

  Widget _buildDepositedCellCard({
    required bool isDark,
    required ActiveCell cell,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.lock,
                      size: 20,
                      color: AppColors.primary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cell.cellNumber,
                      style: AppTextStyles.title(isDark).copyWith(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.location,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cell.lockerName,
                        style: AppTextStyles.body(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Iniziato: ${cell.formattedStartTime}',
                      style: AppTextStyles.bodySecondary(isDark),
                    ),
                  ],
                ),
                if (cell.formattedEndTime != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 16,
                        color: AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cell.formattedEndTime!,
                        style: AppTextStyles.bodySecondary(isDark),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _handleUnlockDeposited(cell),
                child: const Text(
                  'Sblocca cella',
                  style: TextStyle(
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

  Widget _buildPickupCellCard({
    required bool isDark,
    required ActiveCell cell,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.cart_fill,
                      size: 20,
                      color: AppColors.primary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cell.cellNumber,
                      style: AppTextStyles.title(isDark).copyWith(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.location,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cell.lockerName,
                        style: AppTextStyles.body(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Consegnato: ${cell.formattedStartTime}',
                      style: AppTextStyles.bodySecondary(isDark),
                    ),
                  ],
                ),
                if (cell.formattedEndTime != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 16,
                        color: AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ritira entro: ${cell.formattedEndTime}',
                        style: AppTextStyles.bodySecondary(isDark),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _handleUnlockPickup(cell),
                child: const Text(
                  'Sblocca cella',
                  style: TextStyle(
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
}
