import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isRefreshing = false;
  List<LockerCell> _cells = [];
  String? _errorMessage;
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  static const Duration _cellsCacheTtl = Duration(minutes: 5);
  static final Map<String, _CellsCacheEntry> _memoryCellsCache = {};

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
    _restoreCellsCache().then((_) {
      _loadCells(showLoading: _cells.isEmpty);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCells({required bool showLoading}) async {
    setState(() {
      if (showLoading) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
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
        _isRefreshing = false;
      });
      await _saveCellsCache(filteredCells);
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento: ${e.toString()}';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  String get _cellsCacheKey => 'locker_cells_cache_v1_${widget.locker.id}';
  String get _cellsCacheAtKey => 'locker_cells_cache_at_v1_${widget.locker.id}';

  Map<String, dynamic> _cellToJson(LockerCell c) {
    return {
      'id': c.id,
      'cellNumber': c.cellNumber,
      'type': c.type.name,
      'size': c.size.name,
      'isAvailable': c.isAvailable,
      'itemName': c.itemName,
      'itemDescription': c.itemDescription,
      'itemImageUrl': c.itemImageUrl,
      'pricePerHour': c.pricePerHour,
      'pricePerDay': c.pricePerDay,
      'availableUntil': c.availableUntil?.toIso8601String(),
    };
  }

  Future<void> _restoreCellsCache() async {
    final lockerId = widget.locker.id;
    final mem = _memoryCellsCache[lockerId];
    if (mem != null &&
        DateTime.now().difference(mem.cachedAt) < _cellsCacheTtl &&
        mem.cells.isNotEmpty) {
      setState(() {
        _cells = mem.cells;
        _isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cellsCacheKey);
      final cachedAtMs = prefs.getInt(_cellsCacheAtKey);
      if (raw == null || cachedAtMs == null) return;

      final cachedAt =
          DateTime.fromMillisecondsSinceEpoch(cachedAtMs, isUtc: false);
      if (DateTime.now().difference(cachedAt) > _cellsCacheTtl) {
        // Cache troppo vecchia: la useremo comunque solo se non abbiamo nulla,
        // ma non blocchiamo.
      }

      final decoded = jsonDecode(raw) as List<dynamic>;
      final cells = decoded
          .map((e) => LockerCell.fromJson(e as Map<String, dynamic>))
          .where((cell) =>
              (cell.type == CellType.borrow || cell.type == CellType.deposit) &&
              cell.isAvailable)
          .toList();

      if (!mounted || cells.isEmpty) return;
      setState(() {
        _cells = cells;
        _isLoading = false;
      });
      _memoryCellsCache[lockerId] = _CellsCacheEntry(cells, DateTime.now());
    } catch (_) {
      // ignora cache corrotta
    }
  }

  Future<void> _saveCellsCache(List<LockerCell> cells) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = cells.map(_cellToJson).toList();
      await prefs.setString(_cellsCacheKey, jsonEncode(payload));
      await prefs.setInt(_cellsCacheAtKey, DateTime.now().millisecondsSinceEpoch);
      _memoryCellsCache[widget.locker.id] =
          _CellsCacheEntry(List<LockerCell>.from(cells), DateTime.now());
    } catch (_) {}
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

        final hasBorrow = _cells.any((c) => c.type == CellType.borrow);
        final hasDeposit = _cells.any((c) => c.type == CellType.deposit);

        final tabs = <_LockerTab>[];
        if (hasBorrow) {
          tabs.add(const _LockerTab(
            keyId: 'borrow',
            title: 'Prestito',
            icon: CupertinoIcons.arrow_down_circle,
          ));
        }
        if (hasDeposit) {
          tabs.add(const _LockerTab(
            keyId: 'deposit',
            title: 'Deposito',
            icon: CupertinoIcons.cube_box,
          ));
        }

        // Se non abbiamo ancora celle (loading/errore), mostriamo una singola pagina “stato”
        final showPager = tabs.length > 1 && !_isLoading && _errorMessage == null;
        if (!showPager) {
          _currentPageIndex = 0;
        } else if (_currentPageIndex >= tabs.length) {
          _currentPageIndex = 0;
        }

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
            bottom: false,
            child: Column(
              children: [
                // Header minimal con info essenziali + refresh indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        widget.locker.type.icon,
                        size: 20,
                        color: AppColors.primary(isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.locker.type.label,
                          style: AppTextStyles.bodySecondary(isDark).copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (_isRefreshing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CupertinoActivityIndicator(),
                        ),
                    ],
                  ),
                ),
                if (tabs.length > 1)
                  const SizedBox(height: 8),
                if (tabs.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTabSwitcher(
                      isDark: isDark,
                      tabs: tabs,
                      currentIndex: _currentPageIndex,
                      onChanged: (index) {
                        setState(() {
                          _currentPageIndex = index;
                        });
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildStateCard(
                                isDark: isDark,
                                icon: CupertinoIcons.exclamationmark_triangle,
                                title: 'Errore di caricamento',
                                message: _errorMessage!,
                                buttonText: 'Riprova',
                                onPressed: () => _loadCells(showLoading: true),
                              ),
                            )
                          : _cells.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _buildStateCard(
                                    isDark: isDark,
                                    icon: CupertinoIcons.lock,
                                    title: 'Nessuna cella disponibile',
                                    message:
                                        'Non ci sono celle di prestito o deposito disponibili in questo locker.',
                                    buttonText: 'Aggiorna',
                                    onPressed: () => _loadCells(showLoading: true),
                                  ),
                                )
                              : showPager
                                  ? PageView(
                                      controller: _pageController,
                                      onPageChanged: (index) {
                                        setState(() {
                                          _currentPageIndex = index;
                                        });
                                      },
                                      children: tabs.map((tab) {
                                        if (tab.keyId == 'borrow') {
                                          return _buildBorrowPage(isDark);
                                        }
                                        return _buildDepositPage(isDark);
                                      }).toList(),
                                    )
                                  : (hasBorrow
                                      ? _buildBorrowPage(isDark)
                                      : _buildDepositPage(isDark)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSwitcher({
    required bool isDark,
    required List<_LockerTab> tabs,
    required int currentIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.12),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == currentIndex;
          final tab = tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.card(isDark) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                AppColors.shadowColor(isDark).withOpacity(0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.primary(isDark)
                          : AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.text(isDark)
                            : AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBorrowPage(bool isDark) {
    final borrowCells = _cells.where((c) => c.type == CellType.borrow).toList();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _loadCells(showLoading: false)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                _buildSectionHeader(
                  isDark: isDark,
                  title: 'Prendi in prestito',
                  subtitle:
                      'Scegli una cella e visualizza i dettagli dell\'oggetto',
                  icon: CellType.borrow.icon,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: borrowCells
                      .map((c) => _buildBorrowCellSquare(isDark: isDark, cell: c))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepositPage(bool isDark) {
    final depositGroups = _groupDepositCellsBySize();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _loadCells(showLoading: false)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                _buildSectionHeader(
                  isDark: isDark,
                  title: 'Deposita oggetto',
                  subtitle: 'Scegli una dimensione e procedi con l\'affitto',
                  icon: CellType.deposit.icon,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: depositGroups.entries
                      .map((e) => _buildDepositGroupSquare(
                            isDark: isDark,
                            size: e.key,
                            cells: e.value,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor(isDark).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.iconBackground(isDark),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 28,
              color: AppColors.primary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.title(isDark).copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTextStyles.bodySecondary(isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 12),
              borderRadius: BorderRadius.circular(12),
              onPressed: onPressed,
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockerHeader(bool isDark) {
    final availableNow = _cells.length;
    final total = widget.locker.totalCells;
    final hasDescription = widget.locker.description != null &&
        widget.locker.description!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor(isDark).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.locker.type.icon,
                  size: 26,
                  color: AppColors.primary(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.locker.name,
                      style: AppTextStyles.title(isDark).copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.locker.type.label,
                      style: AppTextStyles.bodySecondary(isDark).copyWith(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.borderColor(isDark).withOpacity(0.10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.lock,
                      size: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$availableNow',
                      style: AppTextStyles.body(isDark).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      total > 0 ? '/$total' : '',
                      style: AppTextStyles.bodySecondary(isDark).copyWith(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasDescription) ...[
            const SizedBox(height: 12),
            Text(
              widget.locker.description!,
              style: AppTextStyles.bodySecondary(isDark).copyWith(height: 1.35),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required bool isDark,
    required String title,
    String? subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor(isDark).withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary(isDark).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
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
                  style: AppTextStyles.title(isDark).copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySecondary(isDark).copyWith(
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icona dell'oggetto con sfondo
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary(isDark).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          getIconForItem(cell.itemName),
                          size: squareSize * 0.28, // Ridotto da 0.35 a 0.28
                          color: AppColors.primary(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Nome oggetto
                    if (cell.itemName != null)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            cell.itemName!,
                            style: AppTextStyles.body(isDark).copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icona della dimensione con sfondo
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary(isDark).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          sizeIcon,
                          size: squareSize * 0.28, // Ridotto da 0.35 a 0.28
                          color: AppColors.primary(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Nome dimensione
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          size.label,
                          style: AppTextStyles.body(isDark).copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
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

class _LockerTab {
  final String keyId;
  final String title;
  final IconData icon;

  const _LockerTab({
    required this.keyId,
    required this.title,
    required this.icon,
  });
}

class _CellsCacheEntry {
  final List<LockerCell> cells;
  final DateTime cachedAt;

  _CellsCacheEntry(this.cells, this.cachedAt);
}

