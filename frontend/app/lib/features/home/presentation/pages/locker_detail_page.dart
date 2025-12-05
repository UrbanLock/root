import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/cell_type.dart';
import 'package:app/features/lockers/data/cell_item_icons.dart';
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
                              const SizedBox(height: 20),
                              // Sezione celle per prestito
                              if (_cells.any((c) => c.type == CellType.borrow)) ...[
                                _buildSectionHeader(
                                  isDark: isDark,
                                  title: 'Prendi in prestito',
                                  icon: CellType.borrow.icon,
                                ),
                                const SizedBox(height: 12),
                                // Griglia di quadrati con simboli
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.start,
                                  children: _cells
                                      .where((c) => c.type == CellType.borrow)
                                      .map((cell) => _buildBorrowCellSquare(
                                            isDark: isDark,
                                            cell: cell,
                                          ))
                                      .toList(),
                                ),
                              ],
                              // Separatore minimal tra sezioni
                              if (_cells.any((c) => c.type == CellType.borrow) && 
                                  _cells.any((c) => c.type == CellType.deposit)) ...[
                                const SizedBox(height: 32),
                                Container(
                                  height: 1,
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  color: AppColors.borderColor(isDark).withOpacity(0.2),
                                ),
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
                                // Griglia di quadrati raggruppati per dimensione
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.start,
                                  children: _groupDepositCellsBySize().entries.map((entry) {
                                    return _buildDepositGroupSquare(
                                      isDark: isDark,
                                      size: entry.key,
                                      cells: entry.value,
                                    );
                                  }).toList(),
                                ),
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.iconBackground(isDark),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            widget.locker.type.icon,
            size: 30,
            color: AppColors.primary(isDark),
          ),
        ),
        const SizedBox(height: 12),
        // Nome e tipo
        Text(
          widget.locker.name,
          style: AppTextStyles.title(isDark).copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.locker.type.label,
          style: AppTextStyles.bodySecondary(isDark).copyWith(fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (widget.locker.description != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.locker.description!,
            style: AppTextStyles.body(isDark).copyWith(fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        // Disponibilità
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(10),
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.iconBackground(isDark),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.primary(isDark),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.title(isDark).copyWith(fontSize: 16),
        ),
      ],
    );
  }

  /// Costruisce un quadrato cliccabile con il simbolo dell'oggetto
  Widget _buildBorrowCellSquare({
    required bool isDark,
    required LockerCell cell,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final squareSize = (screenWidth - 48 - 24) / 3; // 3 colonne con spaziatura
    
    return GestureDetector(
      onTap: () => _showBorrowCellDetail(cell, isDark),
      child: Container(
        width: squareSize,
        height: squareSize,
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary(isDark).withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor(isDark).withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Contenuto principale - centrato
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icona dell'oggetto con sfondo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        getIconForItem(cell.itemName),
                        size: squareSize * 0.35, // 35% della dimensione del quadrato
                        color: AppColors.primary(isDark),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Nome oggetto
                    if (cell.itemName != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          cell.itemName!,
                          style: AppTextStyles.body(isDark).copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Numero cella in sovraimpressione - angolo in alto a destra
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.borderColor(isDark).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  cell.cellNumber.replaceAll('Cella ', ''),
                  style: AppTextStyles.body(isDark).copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra il bottom sheet con i dettagli della cella
  void _showBorrowCellDetail(LockerCell cell, bool isDark) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(isDark).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Contenuto
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con icona e numero cella
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary(isDark).withOpacity(0.2),
                                AppColors.primary(isDark).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            getIconForItem(cell.itemName),
                            size: 32,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cell.cellNumber,
                                style: AppTextStyles.body(isDark).copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (cell.itemName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  cell.itemName!,
                                  style: AppTextStyles.title(isDark).copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Foto dell'oggetto
                    if (cell.itemImageUrl != null && cell.itemImageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _showItemPhoto(cell, isDark),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppColors.iconBackground(isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              cell.itemImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPhotoPlaceholder(isDark);
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CupertinoActivityIndicator(
                                    color: AppColors.primary(isDark),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _buildPhotoPlaceholder(isDark),
                    ],
                    // Descrizione
                    if (cell.itemDescription != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        cell.itemDescription!,
                        style: AppTextStyles.body(isDark),
                      ),
                    ],
                    // Durata prestito
                    if (cell.borrowDuration != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock_fill,
                            size: 16,
                            color: AppColors.primary(isDark),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Prestito: ${cell.borrowDuration!.inDays} giorni',
                            style: AppTextStyles.body(isDark).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Pulsante apri
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _handleBorrowCell(cell);
                        },
                        child: const Text(
                          'Apri cella',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
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

  /// Widget placeholder per foto non disponibile
  Widget _buildPhotoPlaceholder(bool isDark) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.iconBackground(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.photo,
            size: 48,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 12),
          Text(
            'Foto non disponibile',
            style: AppTextStyles.bodySecondary(isDark),
          ),
        ],
      ),
    );
  }

  /// Mostra la foto dell'oggetto in un dialog
  void _showItemPhoto(LockerCell cell, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          cell.itemName ?? 'Foto oggetto',
          style: AppTextStyles.title(isDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            if (cell.itemImageUrl != null && cell.itemImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  cell.itemImageUrl!,
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        color: AppColors.iconBackground(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.photo,
                            size: 64,
                            color: AppColors.textSecondary(isDark),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Immagine non disponibile',
                            style: AppTextStyles.bodySecondary(isDark),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        color: AppColors.iconBackground(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: CupertinoActivityIndicator(
                          color: AppColors.primary(isDark),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.iconBackground(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.photo,
                      size: 64,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Foto non disponibile',
                      style: AppTextStyles.bodySecondary(isDark),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  /// Costruisce un quadrato cliccabile per un gruppo di celle di deposito della stessa dimensione
  Widget _buildDepositGroupSquare({
    required bool isDark,
    required CellSize size,
    required List<LockerCell> cells,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final squareSize = (screenWidth - 48 - 24) / 3; // 3 colonne con spaziatura
    final referenceCell = cells.first;
    final availableCount = cells.where((c) => c.isAvailable).length;
    
    // Icona in base alla dimensione
    IconData sizeIcon;
    switch (size) {
      case CellSize.small:
        sizeIcon = CupertinoIcons.square;
        break;
      case CellSize.medium:
        sizeIcon = CupertinoIcons.square_grid_2x2;
        break;
      case CellSize.large:
        sizeIcon = CupertinoIcons.square_stack_3d_up_fill;
        break;
      case CellSize.extraLarge:
        sizeIcon = CupertinoIcons.square_stack_3d_up_fill;
        break;
    }
    
    return GestureDetector(
      onTap: () => _showDepositGroupDetail(size, cells, isDark),
      child: Container(
        width: squareSize,
        height: squareSize,
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary(isDark).withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor(isDark).withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Contenuto principale - centrato
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icona della dimensione con sfondo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        sizeIcon,
                        size: squareSize * 0.35, // 35% della dimensione del quadrato
                        color: AppColors.primary(isDark),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Nome dimensione
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        size.label,
                        style: AppTextStyles.body(isDark).copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Numero celle disponibili in sovraimpressione - angolo in alto a destra
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: availableCount > 0 
                      ? CupertinoColors.systemGreen.withOpacity(0.2)
                      : AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: availableCount > 0
                        ? CupertinoColors.systemGreen.withOpacity(0.5)
                        : AppColors.borderColor(isDark).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$availableCount',
                  style: AppTextStyles.body(isDark).copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: availableCount > 0
                        ? CupertinoColors.systemGreen
                        : AppColors.textSecondary(isDark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra il bottom sheet con i dettagli di un gruppo di celle di deposito
  void _showDepositGroupDetail(CellSize size, List<LockerCell> cells, bool isDark) {
    final referenceCell = cells.first;
    final availableCount = cells.where((c) => c.isAvailable).length;
    final totalCount = cells.length;
    // Icona in base alla dimensione
    IconData sizeIcon;
    switch (size) {
      case CellSize.small:
        sizeIcon = CupertinoIcons.square;
        break;
      case CellSize.medium:
        sizeIcon = CupertinoIcons.square_grid_2x2;
        break;
      case CellSize.large:
        sizeIcon = CupertinoIcons.square_stack_3d_up_fill;
        break;
      case CellSize.extraLarge:
        sizeIcon = CupertinoIcons.square_stack_3d_up_fill;
        break;
    }
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(isDark).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Contenuto
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con icona e numero cella
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.iconBackground(isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            sizeIcon,
                            size: 32,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                size.label,
                                style: AppTextStyles.title(isDark).copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$availableCount di $totalCount celle disponibili',
                                style: AppTextStyles.body(isDark).copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Dettagli dimensione
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.iconBackground(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.arrow_left_right,
                                size: 16,
                                color: AppColors.textSecondary(isDark),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                size.dimensions,
                                style: AppTextStyles.body(isDark),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Disponibilità
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.lock_fill,
                          size: 16,
                          color: availableCount > 0 
                              ? CupertinoColors.systemGreen 
                              : CupertinoColors.systemRed,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          availableCount > 0 
                              ? '$availableCount ${availableCount == 1 ? 'cella disponibile' : 'celle disponibili'}'
                              : 'Nessuna cella disponibile',
                          style: AppTextStyles.body(isDark).copyWith(
                            fontWeight: FontWeight.w600,
                            color: availableCount > 0 
                                ? CupertinoColors.systemGreen 
                                : CupertinoColors.systemRed,
                          ),
                        ),
                      ],
                    ),
                    // Prezzo
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.money_dollar_circle_fill,
                            size: 20,
                            color: AppColors.primary(isDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '€${referenceCell.pricePerDay.toStringAsFixed(2)}/giorno',
                                  style: AppTextStyles.title(isDark).copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary(isDark),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'o €${referenceCell.pricePerHour.toStringAsFixed(2)}/ora',
                                  style: AppTextStyles.bodySecondary(isDark).copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Pulsante affitta
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: availableCount > 0 ? () {
                          Navigator.of(context).pop();
                          // Prendi la prima cella disponibile
                          final availableCell = cells.firstWhere((c) => c.isAvailable);
                          _handleDepositCell(availableCell);
                        } : null,
                        child: const Text(
                          'Affitta cella',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
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

