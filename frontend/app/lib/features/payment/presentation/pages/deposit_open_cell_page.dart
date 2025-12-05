import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/notifications/notification_service.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/data/repositories/cell_repository_mock.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/cell_type.dart';
import 'package:app/features/reports/presentation/pages/report_issue_page.dart';

/// Pagina per aprire una cella di deposito tramite Bluetooth
/// 
/// **Flusso:**
/// 1. Ricerca del locker via Bluetooth
/// 2. Se Bluetooth non attivo, richiesta attivazione con refresh automatico
/// 3. Una volta connesso, pulsante per aprire la cella
/// 4. L'utente mette i suoi oggetti dentro
/// 5. Attesa chiusura sportello (simulata con 3 secondi)
/// 6. Schermata di conferma chiusura
/// 
/// **TODO quando il backend sarà pronto:**
/// - UUID reale del locker dal backend
/// - Comando Bluetooth reale per aprire la cella
/// - Rilevamento chiusura tramite sensore/signale Bluetooth
/// - Salvataggio deposito nel backend (POST /api/v1/deposits)
class DepositOpenCellPage extends StatefulWidget {
  final ThemeManager themeManager;
  final LockerCell cell;
  final String lockerName;
  final String lockerId;
  final Duration duration; // Durata selezionata dall'utente
  final bool skipBluetoothVerification; // Se true, salta la verifica Bluetooth e apre direttamente

  const DepositOpenCellPage({
    super.key,
    required this.themeManager,
    required this.cell,
    required this.lockerName,
    required this.lockerId,
    this.duration = const Duration(days: 1), // Default 24 ore
    this.skipBluetoothVerification = false, // Default: verifica Bluetooth
  });

  @override
  State<DepositOpenCellPage> createState() => _DepositOpenCellPageState();
}

class _DepositOpenCellPageState extends State<DepositOpenCellPage> {
  // Stati Bluetooth
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  bool _lockerFound = false;
  bool _lockerConnected = false;
  bool _waitingForBluetoothActivation = false;
  bool _showRetryButton = false; // Flag per mostrare il pulsante "Riprova" solo dopo un delay
  String _statusMessage = 'Preparazione...';
  
  // Stati apertura/chiusura cella
  bool _cellOpened = false;
  bool _waitingForDoorClose = false;
  
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  Timer? _doorCloseTimer;

  @override
  void initState() {
    super.initState();
    // Se skipBluetoothVerification è true, apri direttamente la cella
    if (widget.skipBluetoothVerification) {
      // Simula connessione già stabilita e apri direttamente
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _lockerFound = true;
            _lockerConnected = true;
            _isBluetoothEnabled = true;
            _isScanning = false;
          });
          // Apri direttamente la cella
          _openCell();
        }
      });
    } else {
      _checkBluetoothAndStartScan();
    }
  }

  @override
  void dispose() {
    _doorCloseTimer?.cancel();
    _bluetoothStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  /// Controlla lo stato Bluetooth e avvia la ricerca
  Future<void> _checkBluetoothAndStartScan() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      
      if (adapterState != BluetoothAdapterState.on) {
        setState(() {
          _isBluetoothEnabled = false;
          _waitingForBluetoothActivation = true;
          _statusMessage = 'Attivazione Bluetooth richiesta';
        });
        
        _setupBluetoothListener();
        _requestEnableBluetooth();
        return;
      }

      setState(() {
        _isBluetoothEnabled = true;
        _waitingForBluetoothActivation = false;
      });

      _setupBluetoothListener();
      // Avvia la ricerca dopo un breve delay per assicurarsi che sia tutto pronto
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_lockerFound && !_isScanning) {
          _startScan();
        }
      });
    } catch (e) {
      debugPrint('❌ [BLUETOOTH] Errore: $e');
      setState(() {
        _statusMessage = 'Errore: $e';
        _isScanning = false;
      });
    }
  }

  /// Imposta il listener per i cambiamenti dello stato Bluetooth
  void _setupBluetoothListener() {
    _bluetoothStateSubscription?.cancel();
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      debugPrint('📡 [BLUETOOTH] Stato cambiato: $state');
      
      if (state == BluetoothAdapterState.on) {
        setState(() {
          _isBluetoothEnabled = true;
          _waitingForBluetoothActivation = false;
          _statusMessage = 'Ricerca locker in corso...';
        });
        
        if (!_isScanning && !_lockerFound && mounted) {
          debugPrint('📡 [BLUETOOTH] Bluetooth attivato, avvio scansione...');
          // Avvia la ricerca dopo un breve delay per assicurarsi che sia tutto pronto
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_lockerFound && !_isScanning) {
              _startScan();
            }
          });
        }
      } else if (state == BluetoothAdapterState.off) {
        setState(() {
          _isBluetoothEnabled = false;
          _lockerFound = false;
          _lockerConnected = false;
          _statusMessage = 'Bluetooth disattivato';
        });
      }
    });
  }

  /// Richiede l'attivazione del Bluetooth (popup di sistema)
  Future<void> _requestEnableBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      debugPrint('❌ [BLUETOOTH] Errore attivazione: $e');
    }
  }

  /// Avvia la ricerca del locker
  Future<void> _startScan() async {
    if (_isScanning) {
      debugPrint('⚠️ [SCAN] Scansione già in corso, ignoro');
      return;
    }

    debugPrint('🔍 [SCAN] Avvio ricerca locker...');
    try {
      setState(() {
        _isScanning = true;
        _statusMessage = 'Ricerca locker in corso...';
        _lockerFound = false;
        _lockerConnected = false;
        _showRetryButton = false; // Nascondi il pulsante "Riprova" quando inizia una nuova scansione
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      debugPrint('✅ [SCAN] Scansione avviata');

      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!_lockerFound && _isScanning) {
          // ⚠️ SOLO PER TESTING: Simula ritrovamento dopo 2 secondi
          // IN PRODUZIONE: Verificare UUID o nome del dispositivo
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isScanning && !_lockerFound) {
              debugPrint('✅ [SCAN] Simulo ritrovamento locker');
              setState(() {
                _lockerFound = true;
                _lockerConnected = true;
                _isScanning = false;
                _statusMessage = 'Locker connesso';
                _showRetryButton = false; // Nascondi il pulsante "Riprova" quando il locker è trovato
              });
              FlutterBluePlus.stopScan();
              debugPrint('✅ [SCAN] Locker connesso, scansione fermata');
            }
          });
        }
      });

      // Timeout dopo 10 secondi
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isScanning && !_lockerFound) {
          debugPrint('⏱️ [SCAN] Timeout - locker non trovato');
          setState(() {
            _isScanning = false;
            _statusMessage = 'Locker non trovato. Riprova più tardi.';
            _showRetryButton = true; // Mostra il pulsante "Riprova" dopo il timeout
          });
          FlutterBluePlus.stopScan();
        }
      });
      
      // Mostra il pulsante "Riprova" solo dopo almeno 5 secondi di scansione fallita
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_lockerFound && !_lockerConnected && _isBluetoothEnabled && !_isScanning) {
          setState(() {
            _showRetryButton = true;
          });
        }
      });
    } catch (e) {
      debugPrint('❌ [BLUETOOTH] Errore durante la ricerca: $e');
      setState(() {
        _statusMessage = 'Errore durante la ricerca: $e';
        _isScanning = false;
      });
    }
  }

  /// Gestisce la segnalazione di un problema
  void _handleReport() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ReportIssuePage(
          themeManager: widget.themeManager,
          lockerId: widget.lockerId,
          lockerName: widget.lockerName,
          cellId: widget.cell.id,
          cellNumber: widget.cell.cellNumber,
        ),
      ),
    );
  }

  /// Apre la cella e attende la chiusura
  Future<void> _openCell() async {
    setState(() {
      _cellOpened = true;
      _waitingForDoorClose = false; // Prima l'utente deve mettere gli oggetti
      _statusMessage = 'Cella aperta. Metti i tuoi oggetti dentro e chiudi lo sportello.';
    });


    // ⚠️ SOLO PER TESTING: Timer di 3 secondi per simulare chiusura
    // IN PRODUZIONE: Rilevare chiusura tramite sensore Bluetooth/backend che invierà segnale
    // Il backend riceverà il segnale dal locker fisico e notificherà l'app
    _doorCloseTimer?.cancel();
    setState(() {
      _waitingForDoorClose = true;
      _statusMessage = 'In attesa della chiusura dello sportello...';
    });
    // Dopo 3 secondi, simula chiusura
    _doorCloseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _waitingForDoorClose) {
        _handleDoorClosed();
      }
    });
    debugPrint('✅ [TIMER] Timer di 3 secondi avviato per simulare chiusura');
  }

  /// Gestisce la chiusura dello sportello
  /// 
  /// **TODO BACKEND**: Chiamare API per salvare il deposito
  /// POST /api/v1/deposits
  /// Body: { lockerId, cellId, startTime, endTime, price }
  Future<void> _handleDoorClosed() async {
    debugPrint('🔒 [CLOSE] Gestisco chiusura sportello');
    
    if (!mounted) {
      debugPrint('❌ [CLOSE] Widget non montato');
      return;
    }
    
    if (!_waitingForDoorClose) {
      debugPrint('❌ [CLOSE] Non più in attesa di chiusura');
      return;
    }
    
    _doorCloseTimer?.cancel();
    _doorCloseTimer = null;
    
    setState(() {
      _waitingForDoorClose = false;
    });

    // TODO BACKEND: Salvare deposito nel backend
    // await depositRepository.createDeposit(...);

    final repository = AppDependencies.cellRepository;
    
    // Se skipBluetoothVerification è false, significa che è uno sblocco di una cella già depositata
    // In questo caso, rimuovi la cella dalle attive e aggiungi allo storico
    if (!widget.skipBluetoothVerification) {
      debugPrint('📱 [CLOSE] Rimuovo cella dalle celle attive (sblocco)...');
      if (repository != null) {
        try {
          await repository.notifyCellClosed(widget.cell.id);
        } catch (e) {
          debugPrint('⚠️ [CLOSE] Errore notifica backend: $e');
        }
      }
    } else {
      // È un nuovo deposito, aggiungi alle celle attive
      debugPrint('📱 [CLOSE] Aggiungo cella alle celle attive (nuovo deposito)...');
      // ⚠️ SOLO PER TESTING: Aggiungi la cella alle celle attive
      // IN PRODUZIONE: Il backend aggiungerà automaticamente quando viene aperta una cella
      final activeCell = ActiveCell(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lockerId: widget.lockerId,
        lockerName: widget.lockerName,
        lockerType: 'Deposito',
        cellNumber: widget.cell.cellNumber,
        cellId: widget.cell.id,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(widget.duration),
        type: widget.cell.type == CellType.pickup 
            ? CellUsageType.pickup 
            : CellUsageType.deposited,
      );
      
      // Aggiungi alle celle attive (solo per testing, in produzione sarà il backend)
      if (repository is CellRepositoryMock) {
        repository.addActiveCell(activeCell);
      }
      
      debugPrint('📱 [CLOSE] Programmo promemoria per ritiro deposito...');
      // Programma promemoria per ritirare il deposito
      try {
        await NotificationService().scheduleDepositPickupReminder(activeCell);
      } catch (e) {
        debugPrint('⚠️ [NOTIFICATION] Errore nella programmazione promemoria: $e');
      }
    }

    debugPrint('📱 [CLOSE] Navigo alla schermata di conferma...');
    if (mounted) {
      try {
        await Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => _DepositClosedConfirmationPage(
              themeManager: widget.themeManager,
              cellNumber: widget.cell.cellNumber,
              lockerName: widget.lockerName,
              cellSize: widget.cell.size.label,
              isPickup: widget.cell.type == CellType.pickup,
              isUnlock: !widget.skipBluetoothVerification,
            ),
          ),
        );
        debugPrint('✅ [CLOSE] Navigazione completata');
      } catch (e) {
        debugPrint('❌ [CLOSE] Errore durante navigazione: $e');
      }
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
              widget.cell.type == CellType.pickup 
                  ? 'Ritira ordine'
                  : !widget.skipBluetoothVerification
                      ? 'Ritira oggetti'
                      : 'Deposita oggetti',
              style: AppTextStyles.title(isDark),
            ),
            leading: CupertinoNavigationBarBackButton(
              color: AppColors.primary(isDark),
              onPressed: () {
                _doorCloseTimer?.cancel();
                FlutterBluePlus.stopScan();
                Navigator.of(context).pop();
              },
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_cellOpened && _waitingForDoorClose) ...[
                    // Schermata attesa chiusura sportello
                    _buildWaitingForCloseScreen(isDark),
                  ] else if (_cellOpened && !_waitingForDoorClose) ...[
                    // Cella aperta, in attesa che l'utente metta/ritiri oggetti
                    _buildCellOpenedScreen(isDark),
                  ] else if (_lockerConnected && !_cellOpened) ...[
                    // Schermata locker connesso - pulsante apri
                    _buildConnectedScreen(isDark),
                  ] else ...[
                    // Schermata ricerca Bluetooth
                    _buildBluetoothScreen(isDark),
                  ],
                  const Spacer(),
                  // Pulsante segnala problema (posizione uniforme in tutte le pagine)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: _handleReport,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 18,
                          color: AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Segnala problema',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary(isDark),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLockerInfo(isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBluetoothScreen(bool isDark) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: _isBluetoothEnabled
                ? AppColors.primary(isDark).withOpacity(0.1)
                : AppColors.textSecondary(isDark).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.bluetooth,
            size: 60,
            color: _isBluetoothEnabled
                ? AppColors.primary(isDark)
                : AppColors.textSecondary(isDark),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _statusMessage,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _isBluetoothEnabled
              ? 'Avvicinati al locker per aprire la cella'
              : 'Attiva il Bluetooth per continuare',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        if (_isScanning || _waitingForBluetoothActivation)
          Column(
            children: [
              const CupertinoActivityIndicator(radius: 20),
              const SizedBox(height: 16),
              Text(
                _waitingForBluetoothActivation
                    ? 'In attesa dell\'attivazione del Bluetooth...'
                    : 'Ricerca in corso...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        // Mostriamo il pulsante "Riprova" solo dopo un delay e se la scansione è fallita
        if (_showRetryButton && !_isScanning && !_lockerFound && _isBluetoothEnabled && !_waitingForBluetoothActivation && !_lockerConnected) ...[
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                setState(() {
                  _showRetryButton = false; // Nascondi il pulsante quando si riprova
                });
                _checkBluetoothAndStartScan();
              },
              child: Text(
                'Riprova',
                style: TextStyle(
                  color: AppColors.text(isDark),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLockerInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.location_solid,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.lockerName,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.text(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                CupertinoIcons.lock,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 8),
              Text(
                widget.cell.cellNumber,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedScreen(bool isDark) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.success(isDark).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.check_mark_circled_solid,
            size: 60,
            color: AppColors.success(isDark),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Locker connesso!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Pronto per aprire la cella',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(vertical: 16),
            borderRadius: BorderRadius.circular(12),
            onPressed: _openCell,
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
    );
  }

  Widget _buildCellOpenedScreen(bool isDark) {
    // Determina il tipo di operazione in base al tipo di cella e se è uno sblocco
    final bool isPickup = widget.cell.type == CellType.pickup;
    final bool isUnlock = !widget.skipBluetoothVerification; // Se false, è uno sblocco per ritirare
    
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary(isDark).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.lock_open,
            size: 60,
            color: AppColors.primary(isDark),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          isPickup
              ? 'Ritira il tuo ordine'
              : isUnlock
                  ? 'Ritira i tuoi oggetti'
                  : 'Deposita i tuoi oggetti',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          isPickup
              ? 'Ritira il tuo ordine dalla cella'
              : isUnlock
                  ? 'Ritira i tuoi oggetti dalla cella'
                  : 'Metti i tuoi oggetti dentro la cella',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWaitingForCloseScreen(bool isDark) {
    // Determina il tipo di operazione in base al tipo di cella e se è uno sblocco
    final bool isPickup = widget.cell.type == CellType.pickup;
    final bool isUnlock = !widget.skipBluetoothVerification; // Se false, è uno sblocco per ritirare
    
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary(isDark).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.lock_open,
            size: 60,
            color: AppColors.primary(isDark),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          isPickup
              ? 'Ritira il tuo ordine'
              : isUnlock
                  ? 'Ritira i tuoi oggetti'
                  : 'Deposita i tuoi oggetti',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          isPickup
              ? 'Ritira il tuo ordine dalla cella e chiudi correttamente lo sportello'
              : isUnlock
                  ? 'Ritira i tuoi oggetti dalla cella e chiudi correttamente lo sportello'
                  : 'Metti i tuoi oggetti dentro la cella e chiudi correttamente lo sportello',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        const CupertinoActivityIndicator(radius: 20),
        const SizedBox(height: 16),
        Text(
          'In attesa della chiusura dello sportello...',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Schermata di conferma chiusura sportello per deposito/ritiro/pickup
class _DepositClosedConfirmationPage extends StatelessWidget {
  final ThemeManager themeManager;
  final String cellNumber;
  final String lockerName;
  final String cellSize;
  final bool isPickup;
  final bool isUnlock;

  const _DepositClosedConfirmationPage({
    required this.themeManager,
    required this.cellNumber,
    required this.lockerName,
    required this.cellSize,
    this.isPickup = false,
    this.isUnlock = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, _) {
        final isDark = themeManager.isDarkMode;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: Text(
              'Conferma',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.success(isDark).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      size: 60,
                      color: AppColors.success(isDark),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Sportello chiuso correttamente',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPickup
                        ? 'Il tuo ordine è stato ritirato con successo'
                        : isUnlock
                            ? 'I tuoi oggetti sono stati ritirati con successo'
                            : 'Il tuo oggetto è stato depositato con successo',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 16,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lockerName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.text(isDark),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.lock,
                              size: 16,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cellNumber,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.square_grid_2x2,
                              size: 16,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cellSize,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () {
                        // Torna alla home
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        'OK',
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
          ),
        );
      },
    );
  }
}

