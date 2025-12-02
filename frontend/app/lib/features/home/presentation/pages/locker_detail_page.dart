import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/cell_type.dart';
import 'package:app/features/profile/presentation/pages/open_cell_page.dart';
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:app/features/payment/presentation/pages/deposit_payment_page.dart';

/// Pagina di dettaglio di un locker
/// 
/// Mostra tutte le celle disponibili del locker, divise per tipo:
/// - Celle per prestito: descrizione contenuto + pulsante "Apri"
/// - Celle per deposito: dimensione + costo + pulsante "Affitta"
/// - Celle per ritiro prodotti: NON mostrate in questa sezione
/// 
/// **TODO quando il backend sarà pronto:**
/// - Caricare celle dal backend (GET /api/v1/lockers/:id/cells)
/// - Aggiornare disponibilità in tempo reale
/// - Implementare prenotazione/pagamento tramite backend
class LockerDetailPage extends StatefulWidget {
  final ThemeManager themeManager;
  final Locker locker;
  final bool isAuthenticated;
  final Function(bool)? onAuthenticationChanged;

  const LockerDetailPage({
    super.key,
    required this.themeManager,
    required this.locker,
    this.isAuthenticated = false,
    this.onAuthenticationChanged,
  });

  @override
  State<LockerDetailPage> createState() => _LockerDetailPageState();
}

class _LockerDetailPageState extends State<LockerDetailPage> {
  bool _isLoading = true;
  List<LockerCell> _cells = [];
  String? _errorMessage;

  /// Raggruppa le celle di deposito per dimensione
  Map<CellSize, List<LockerCell>> _groupDepositCellsBySize() {
    final depositCells = _cells.where((c) => c.type == CellType.deposit).toList();
    final grouped = <CellSize, List<LockerCell>>{};
    
    for (final cell in depositCells) {
      if (!grouped.containsKey(cell.size)) {
        grouped[cell.size] = [];
      }
      grouped[cell.size]!.add(cell);
    }
    
    return grouped;
  }
  late bool _isAuthenticated;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.isAuthenticated;
    _loadCells();
  }

  Future<void> _loadCells() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Quando il backend sarà pronto, caricare celle dal repository
      final repository = AppDependencies.lockerRepository;
      final allCells = await repository.getLockerCells(widget.locker.id);
      
      // Filtra le celle: escludi pickup, mostra solo borrow e deposit DISPONIBILI
      final filteredCells = allCells.where((cell) => 
        (cell.type == CellType.borrow || cell.type == CellType.deposit) &&
        cell.isAvailable
      ).toList();
      
      setState(() {
        _cells = filteredCells;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Mostra dialog per richiedere il login
  void _showLoginRequiredDialog() {
    final isDark = widget.themeManager.isDarkMode;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Accesso richiesto'),
        content: const Text(
          'Per prendere in prestito o affittare una cella è necessario effettuare l\'accesso.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Accedi'),
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToLogin();
            },
          ),
        ],
      ),
    );
  }

  /// Naviga alla pagina di login
  Future<void> _navigateToLogin() async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => LoginPage(
          themeManager: widget.themeManager,
          onLoginSuccess: (success) {
            if (success) {
              setState(() {
                _isAuthenticated = true;
              });
              widget.onAuthenticationChanged?.call(true);
            }
          },
        ),
      ),
    );
    
    // Se il login è riuscito, result sarà true
    if (result == true || _isAuthenticated) {
      // L'utente è ora autenticato, può procedere
    }
  }

  /// Gestisce il click su una cella di prestito
  void _handleBorrowCell(LockerCell cell) {
    // Verifica autenticazione
    if (!_isAuthenticated) {
      _showLoginRequiredDialog();
      return;
    }

    // Mostra popup con avviso sulla foto richiesta al ritorno
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Prendi in prestito: ${cell.itemName ?? "Oggetto"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cell.itemDescription != null) ...[
              Text(
                cell.itemDescription!,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            if (cell.borrowDuration != null) ...[
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.clock,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tempo di prestito: ${cell.borrowDuration!.inDays} giorni',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.camera,
                    size: 16,
                    color: CupertinoColors.systemOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Al ritorno dell\'oggetto sarà richiesta una foto per verificare le condizioni.',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemOrange.darkColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Apri'),
            onPressed: () {
              Navigator.of(context).pop();
              // Naviga alla procedura di sblocco cella
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => OpenCellPage(
                    themeManager: widget.themeManager,
                    cell: cell,
                    lockerName: widget.locker.name,
                    lockerId: widget.locker.id,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Gestisce il click su una cella di deposito
  void _handleDepositCell(LockerCell cell) {
    // Verifica autenticazione
    if (!_isAuthenticated) {
      _showLoginRequiredDialog();
      return;
    }

    final priceInfo = '€${cell.pricePerDay.toStringAsFixed(2)}/giorno o €${cell.pricePerHour.toStringAsFixed(2)}/ora';
    final sizeInfo = '${cell.size.label} (${cell.size.dimensions})';

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Affitta cella'),
        content: Text(
          'Dimensione: $sizeInfo\nCosto: $priceInfo\n\nLa cella sarà disponibile per 24 ore.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Affitta'),
            onPressed: () {
              Navigator.of(context).pop();
              // Naviga alla verifica Bluetooth (stessa schermata del prestito)
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => OpenCellPage(
                    themeManager: widget.themeManager,
                    cell: cell,
                    lockerName: widget.locker.name,
                    lockerId: widget.locker.id,
                    // Callback chiamato dopo verifica Bluetooth per navigare al pagamento
                    onVerificationComplete: () {
                      Navigator.of(context).pushReplacement(
                        CupertinoPageRoute(
                          builder: (context) => DepositPaymentPage(
                            themeManager: widget.themeManager,
                            cell: cell,
                            lockerName: widget.locker.name,
                            lockerId: widget.locker.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
                                onPressed: _loadCells,
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _cells.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.lock,
                                    size: 64,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Nessuna cella disponibile',
                                    style: AppTextStyles.title(isDark),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Non ci sono celle di prestito o deposito disponibili in questo locker',
                                    style: AppTextStyles.bodySecondary(isDark),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              // Header con info locker
                              _buildLockerHeader(isDark),
                              const SizedBox(height: 32),
                              // Sezione celle per prestito
                              if (_cells.any((c) => c.type == CellType.borrow)) ...[
                                _buildSectionHeader(
                                  isDark: isDark,
                                  title: 'Prendi in prestito',
                                  icon: CellType.borrow.icon,
                                ),
                                const SizedBox(height: 12),
                                ..._cells
                                    .where((c) => c.type == CellType.borrow)
                                    .map((cell) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: _buildBorrowCellCard(
                                            isDark: isDark,
                                            cell: cell,
                                          ),
                                        )),
                                const SizedBox(height: 32),
                              ],
                              // Sezione celle per deposito (raggruppate per dimensione)
                              if (_cells.any((c) => c.type == CellType.deposit)) ...[
                                _buildSectionHeader(
                                  isDark: isDark,
                                  title: 'Deposita oggetto',
                                  icon: CellType.deposit.icon,
                                ),
                                const SizedBox(height: 12),
                                ..._groupDepositCellsBySize().entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildDepositGroupCard(
                                      isDark: isDark,
                                      size: entry.key,
                                      cells: entry.value,
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
          ),
        );
      },
    );
  }

  Widget _buildLockerHeader(bool isDark) {
    return Column(
      children: [
        // Icona locker
        Container(
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
          const SizedBox(height: 16),
          Text(
            widget.locker.description!,
            style: AppTextStyles.body(isDark),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        // Disponibilità
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.lock,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.locker.availableCells}/${widget.locker.totalCells} celle disponibili',
                style: AppTextStyles.body(isDark),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildBorrowCellCard({
    required bool isDark,
    required LockerCell cell,
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
                // Numero cella
                Text(
                  cell.cellNumber,
                  style: AppTextStyles.body(isDark).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (cell.itemName != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    cell.itemName!,
                    style: AppTextStyles.title(isDark).copyWith(fontSize: 18),
                  ),
                ],
                if (cell.itemDescription != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    cell.itemDescription!,
                    style: AppTextStyles.bodySecondary(isDark),
                  ),
                ],
                if (cell.borrowDuration != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.clock,
                        size: 14,
                        color: AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Prestito: ${cell.borrowDuration!.inDays} giorni',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Pulsante apri
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _handleBorrowCell(cell),
                child: const Text(
                  'Apri',
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

  Widget _buildDepositGroupCard({
    required bool isDark,
    required CellSize size,
    required List<LockerCell> cells,
  }) {
    // Prendi la prima cella come riferimento per prezzo (tutte le celle della stessa dimensione hanno lo stesso prezzo)
    final referenceCell = cells.first;
    final availableCount = cells.length;

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
                // Dimensione
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.square_grid_2x2,
                      size: 20,
                      color: AppColors.primary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      size.label,
                      style: AppTextStyles.title(isDark).copyWith(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  size.dimensions,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                // Disponibilità
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.lock,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$availableCount ${availableCount == 1 ? 'cella disponibile' : 'celle disponibili'}',
                      style: AppTextStyles.body(isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Costo
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.money_dollar_circle,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '€${referenceCell.pricePerDay.toStringAsFixed(2)}/giorno o €${referenceCell.pricePerHour.toStringAsFixed(2)}/ora',
                      style: AppTextStyles.body(isDark).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Pulsante affitta
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _handleDepositCell(referenceCell),
                child: const Text(
                  'Affitta',
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

