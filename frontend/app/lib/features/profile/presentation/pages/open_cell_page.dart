import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:location/location.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/notifications/notification_service.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/domain/repositories/cell_repository.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/reports/presentation/pages/report_issue_page.dart';

/// Pagina per aprire una cella tramite Bluetooth
/// 
/// **Flusso per prestito:**
/// 1. Carica UUID Bluetooth del locker dal backend
/// 2. Ricerca del locker via Bluetooth (cerca dispositivo con UUID corrispondente)
/// 3. Se Bluetooth non attivo, richiesta attivazione con refresh automatico
/// 4. Verifica accoppiamento con backend (UUID, RSSI, geolocalizzazione)
/// 5. Una volta verificato, pulsante per aprire la cella
/// 6. Attesa chiusura sportello (rilevata tramite sensore o timer)
/// 7. Schermata di conferma chiusura
/// 
/// **Flusso per deposito (quando onVerificationComplete è presente):**
/// 1. Carica UUID Bluetooth del locker dal backend
/// 2. Ricerca del locker via Bluetooth
/// 3. Se Bluetooth non attivo, richiesta attivazione con refresh automatico
/// 4. Verifica accoppiamento con backend
/// 5. Una volta verificato, chiama onVerificationComplete (naviga al pagamento)
/// 
/// **Nota:** Il locker deve avere un UUID Bluetooth configurato nel database.
class OpenCellPage extends StatefulWidget {
  final ThemeManager themeManager;
  final LockerCell cell;
  final String lockerName;
  final String lockerId;
  final VoidCallback? onVerificationComplete; // Se presente, chiamato dopo verifica Bluetooth (per deposito)

  const OpenCellPage({
    super.key,
    required this.themeManager,
    required this.cell,
    required this.lockerName,
    required this.lockerId,
    this.onVerificationComplete,
  });

  @override
  State<OpenCellPage> createState() => _OpenCellPageState();
}

class _OpenCellPageState extends State<OpenCellPage> {
  // Stati Bluetooth
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  bool _lockerFound = false;
  bool _lockerConnected = false;
  bool _waitingForBluetoothActivation = false; // Flag per evitare pulsante "Riprova" durante attesa
  String _statusMessage = 'Preparazione...';
  
  // Info Bluetooth (caricate dal backend)
  String? _bluetoothUuid;
  String? _bluetoothName;
  bool _isLoadingBluetoothInfo = false;
  
  // Accoppiamento Bluetooth (verificato dal backend)
  String? _pairingId; // ID accoppiamento verificato dal backend
  bool _isVerifyingPairing = false; // Flag per verifica in corso
  
  // Stati apertura/chiusura cella
  bool _cellOpened = false;
  bool _waitingForDoorClose = false;
  ActiveCell? _activeCell;
  
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  Timer? _doorCloseTimer;
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _loadBluetoothInfo();
  }
  
  /// Carica le informazioni Bluetooth del locker dal backend
  /// Richiede che il locker abbia UUID Bluetooth configurato nel database
  Future<void> _loadBluetoothInfo() async {
    setState(() {
      _isLoadingBluetoothInfo = true;
      _statusMessage = 'Caricamento informazioni Bluetooth...';
    });
    
    try {
      final lockerRepo = AppDependencies.lockerRepository;
      if (lockerRepo == null) {
        setState(() {
          _statusMessage = 'Servizio locker non disponibile';
          _isLoadingBluetoothInfo = false;
        });
        return;
      }
      
      final bluetoothInfo = await lockerRepo.getLockerBluetoothInfo(widget.lockerId);
      
      final bluetoothUuid = bluetoothInfo['bluetoothUuid'] as String?;
      final bluetoothName = bluetoothInfo['bluetoothName'] as String?;
      
      // Verifica che l'UUID sia presente
      if (bluetoothUuid == null || bluetoothUuid.isEmpty) {
        setState(() {
          _statusMessage = 'Locker non configurato correttamente. Contattare l\'amministratore.';
          _isLoadingBluetoothInfo = false;
        });
        return;
      }
      
      setState(() {
        _bluetoothUuid = bluetoothUuid;
        _bluetoothName = bluetoothName;
        _isLoadingBluetoothInfo = false;
      });
      
      // Dopo aver caricato le info, avvia verifica Bluetooth
      _checkBluetoothAndStartScan();
    } on BluetoothNotConfiguredException catch (e) {
      // Il locker non ha UUID Bluetooth configurato
      debugPrint('❌ [ERROR] Locker ${widget.lockerId} non ha UUID Bluetooth configurato: ${e.message}');
      
      setState(() {
        _statusMessage = 'Locker non ha UUID Bluetooth configurato. Contattare l\'amministratore.';
        _isLoadingBluetoothInfo = false;
      });
    } catch (e) {
      debugPrint('❌ [ERROR] Errore nel caricamento info Bluetooth: $e');
      setState(() {
        _statusMessage = 'Errore nel caricamento informazioni Bluetooth. Riprova più tardi.';
        _isLoadingBluetoothInfo = false;
      });
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
    // Verifica che abbiamo un UUID Bluetooth
    if (_bluetoothUuid == null || _bluetoothUuid!.isEmpty) {
      setState(() {
        _statusMessage = 'UUID Bluetooth non disponibile. Contattare l\'amministratore.';
      });
      return;
    }
    
    try {
      // Verifica lo stato corrente
      final adapterState = await FlutterBluePlus.adapterState.first;
      
      if (adapterState != BluetoothAdapterState.on) {
        setState(() {
          _isBluetoothEnabled = false;
          _waitingForBluetoothActivation = true;
          _statusMessage = 'Attivazione Bluetooth richiesta';
        });
        
        // Imposta il listener PRIMA di richiedere l'attivazione
        _setupBluetoothListener();
        _requestEnableBluetooth();
        return;
      }

      // Bluetooth è attivo, avvia la ricerca
      setState(() {
        _isBluetoothEnabled = true;
        _statusMessage = 'Ricerca locker in corso...';
        _isScanning = true;
      });

      // Imposta il listener per cambiamenti futuri
      _setupBluetoothListener();

      await _startScan();
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore: $e';
        _isScanning = false;
      });
    }
  }

  /// Imposta il listener per lo stato Bluetooth
  void _setupBluetoothListener() {
    // Cancella listener precedente se esiste
    _bluetoothStateSubscription?.cancel();
    
    // Crea nuovo listener
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      
      if (state == BluetoothAdapterState.on) {
        // Bluetooth è attivo
        if (!_isBluetoothEnabled) {
          // Bluetooth appena attivato, refresh automatico
          setState(() {
            _isBluetoothEnabled = true;
            _waitingForBluetoothActivation = false;
            _statusMessage = 'Bluetooth attivato. Ricerca locker...';
            _isScanning = true;
          });
          // Avvia la ricerca dopo un breve delay per assicurarsi che sia tutto pronto
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_lockerFound) {
              _startScan();
            }
          });
        }
      } else {
        // Bluetooth non attivo
        if (_isBluetoothEnabled) {
          setState(() {
            _isBluetoothEnabled = false;
            _isScanning = false;
            _waitingForBluetoothActivation = false;
            _statusMessage = 'Bluetooth non attivo';
          });
        }
      }
    });
  }

  /// Richiede l'attivazione del Bluetooth usando il popup di sistema
  Future<void> _requestEnableBluetooth() async {
    try {
      // Usa il popup di sistema per attivare il Bluetooth
      await FlutterBluePlus.turnOn();
      // Il listener rileverà l'attivazione e farà il refresh automatico
      
      // Verifica lo stato dopo un breve delay (in caso l'attivazione sia immediata)
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkBluetoothState();
        }
      });
    } catch (e) {
      // Se non può attivare direttamente, il listener comunque rileverà quando l'utente lo attiva manualmente
      // Non mostriamo dialog personalizzati, solo il popup di sistema
    }
  }

  /// Verifica lo stato Bluetooth e aggiorna se necessario
  Future<void> _checkBluetoothState() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.on && !_isBluetoothEnabled) {
        // Bluetooth è attivo ma lo stato non è aggiornato
        setState(() {
          _isBluetoothEnabled = true;
          _statusMessage = 'Bluetooth attivato. Ricerca locker...';
        });
        if (!_lockerFound) {
          _startScan();
        }
      }
    } catch (e) {
      // Ignora errori
    }
  }

  /// Avvia la ricerca del locker tramite Bluetooth reale
  /// Cerca il dispositivo con UUID corrispondente a quello configurato nel database
  Future<void> _startScan() async {
    // Verifica che abbiamo un UUID Bluetooth
    if (_bluetoothUuid == null || _bluetoothUuid!.isEmpty) {
      setState(() {
        _statusMessage = 'UUID Bluetooth non disponibile. Contattare l\'amministratore.';
        _isScanning = false;
      });
      return;
    }
    
    try {
      setState(() {
        _isScanning = true;
        _statusMessage = 'Ricerca locker in corso...';
        _lockerFound = false;
        _lockerConnected = false;
      });

      debugPrint('🔍 [BLUETOOTH] Avvio scansione Bluetooth reale per UUID: $_bluetoothUuid');
      
      // Avvia scansione Bluetooth reale
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!_lockerFound && _isScanning && mounted) {
          // Cerca il locker tramite UUID o nome Bluetooth
          for (final result in results) {
            final deviceId = result.device.remoteId.toString();
            final deviceName = result.device.platformName;
            
            debugPrint('🔍 [BLUETOOTH] Dispositivo trovato: $deviceId ($deviceName) - RSSI: ${result.rssi}');
            
            // Pre-filtro UUID per UX (matching esatto normalizzato)
            // NOTA: Questo è solo un pre-filtro per UX. La verifica finale rigorosa è fatta dal backend.
            bool isPotentialMatch = false;
            if (_bluetoothUuid != null && _bluetoothUuid!.isNotEmpty) {
              // Normalizza UUID (rimuovi trattini e due punti per confronto)
              final normalizedUuid = _bluetoothUuid!.replaceAll('-', '').replaceAll(':', '').toLowerCase();
              final normalizedDeviceId = deviceId.replaceAll('-', '').replaceAll(':', '').toLowerCase();
              
              // Match ESATTO normalizzato (non permissivo per sicurezza)
              // Il backend farà la verifica finale rigorosa
              isPotentialMatch = normalizedDeviceId == normalizedUuid;
              
              debugPrint('🔍 [BLUETOOTH] Pre-filtro UUID: "$normalizedUuid" vs "$normalizedDeviceId" -> $isPotentialMatch');
            }
            
            // Se non c'è match UUID esatto, salta questo dispositivo
            // Il backend farà la verifica finale, quindi non usiamo fallback nome qui
            if (isPotentialMatch) {
              debugPrint('✅ [BLUETOOTH] Dispositivo potenzialmente corrispondente trovato: $deviceId ($deviceName) - RSSI: ${result.rssi}');
              debugPrint('   ⚠️ [BLUETOOTH] Verifica finale rigorosa sarà fatta dal backend');
              
              // Dispositivo trovato localmente - ora verifica con backend
              // Il backend farà la verifica finale rigorosa (UUID esatto, RSSI, geolocalizzazione)
              FlutterBluePlus.stopScan();
              setState(() {
                _lockerFound = true;
                _isScanning = false;
                _statusMessage = 'Dispositivo trovato. Verifica in corso...';
              });
              
              // Verifica accoppiamento con backend (verifica finale rigorosa)
              _verifyPairingWithBackend(
                bluetoothUuid: deviceId,
                deviceName: deviceName,
                rssi: result.rssi,
              );
              return;
            }
          }
        }
      });

      // Timeout dopo 15 secondi
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _isScanning && !_lockerFound) {
          debugPrint('⏱️ [BLUETOOTH] Timeout scansione: locker non trovato');
          setState(() {
            _isScanning = false;
            _statusMessage = 'Locker non trovato nelle vicinanze. Assicurati di essere vicino al locker e che il Bluetooth sia attivo.';
          });
          FlutterBluePlus.stopScan();
        }
      });
    } catch (e) {
      debugPrint('❌ [BLUETOOTH] Errore durante la ricerca: $e');
      setState(() {
        _statusMessage = 'Errore durante la ricerca: ${e.toString()}';
        _isScanning = false;
      });
    }
  }
  
  /// Verifica accoppiamento Bluetooth con backend
  Future<void> _verifyPairingWithBackend({
    required String bluetoothUuid,
    String? deviceName,
    int? rssi,
  }) async {
    if (_isVerifyingPairing) return; // Evita chiamate multiple
    
    final repository = AppDependencies.cellRepository;
    if (repository == null) {
      setState(() {
        _statusMessage = 'Servizio celle non disponibile';
      });
      return;
    }

    setState(() {
      _isVerifyingPairing = true;
      _statusMessage = 'Verifica in corso...';
    });

    try {
      // Ottieni geolocalizzazione (opzionale, per verifica prossimità)
      Map<String, dynamic>? geolocation;
      try {
        final locationData = await _location.getLocation();
        if (locationData.latitude != null && locationData.longitude != null) {
          geolocation = {
            'lat': locationData.latitude!,
            'lng': locationData.longitude!,
          };
        }
      } catch (_) {
        // Ignora errori geolocalizzazione (opzionale)
      }

      // Chiama backend per verificare accoppiamento
      debugPrint('📤 [VERIFY] Chiamata verifyBluetoothPairing: lockerId=${widget.lockerId}, cellId=${widget.cell.id}, bluetoothUuid=$bluetoothUuid, rssi=$rssi');
      
      final result = await repository.verifyBluetoothPairing(
        lockerId: widget.lockerId,
        cellId: widget.cell.id,
        bluetoothUuid: bluetoothUuid,
        bluetoothRssi: rssi,
        deviceName: deviceName,
        geolocation: geolocation,
      );

      debugPrint('📥 [VERIFY] Risultato ricevuto: verified=${result.verified}, pairingId=${result.pairingId}, reason=${result.reason}, message=${result.message}');
      debugPrint('📥 [VERIFY] cellAssigned: ${result.cellAssigned != null ? "presente" : "null"}');

      // Verifica che tutti i dati necessari siano presenti
      if (result.verified && result.pairingId != null && result.cellAssigned != null) {
        debugPrint('✅ [VERIFY] Verifica riuscita! pairingId=${result.pairingId}');
        // Accoppiamento verificato con successo!
        setState(() {
          _pairingId = result.pairingId;
          _activeCell = result.cellAssigned;
          _lockerConnected = true;
          _isVerifyingPairing = false;
          _statusMessage = 'Locker connesso! Pronto per aprire.';
        });

        // Se è per deposito, chiama callback
        if (widget.onVerificationComplete != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              widget.onVerificationComplete!();
            }
          });
        }
      } else if (result.verified && (result.pairingId == null || result.cellAssigned == null)) {
        // Verifica riuscita ma dati mancanti
        debugPrint('⚠️ [VERIFY] Verifica riuscita ma dati mancanti: pairingId=${result.pairingId}, cellAssigned=${result.cellAssigned != null}');
        setState(() {
          _isVerifyingPairing = false;
          _lockerConnected = false;
          _lockerFound = false;
          _statusMessage = 'Verifica riuscita ma dati incompleti. Riprova più tardi.';
        });
      } else {
        // Verifica fallita
        debugPrint('❌ [VERIFY] Verifica fallita: reason=${result.reason}, message=${result.message}');
        setState(() {
          _isVerifyingPairing = false;
          _lockerConnected = false;
          _lockerFound = false;
          _isScanning = false;
          
          // Mostra messaggio user-friendly basato sul reason
          String errorMessage;
          
          // Personalizza messaggio in base al tipo di errore
          switch (result.reason) {
            case 'connection_error':
              errorMessage = 'Errore di connessione. Verifica la tua connessione internet e riprova.';
              break;
            case 'validation_error':
              // Errore di validazione dal backend (UUID non corrisponde, troppo distante, ecc.)
              errorMessage = result.message ?? 'Verifica fallita. Assicurati di essere vicino al locker corretto.';
              break;
            case 'not_found':
              // Locker o cella non trovata
              errorMessage = result.message ?? 'Locker o cella non trovata. Riprova più tardi.';
              break;
            case 'api_error':
              errorMessage = result.message ?? 'Errore del server. Riprova più tardi.';
              break;
            case 'device_not_found':
              errorMessage = 'Dispositivo non trovato. Assicurati di essere vicino al locker.';
              break;
            case 'too_far':
              errorMessage = 'Sei troppo distante dal locker. Avvicinati e riprova.';
              break;
            case 'unauthorized':
              errorMessage = 'Non hai i permessi per aprire questa cella.';
              break;
            case 'cell_unavailable':
              errorMessage = 'La cella non è disponibile. Prova con un\'altra cella.';
              break;
            case 'parse_error':
              errorMessage = 'Errore nella lettura della risposta del server. Riprova più tardi.';
              break;
            case 'invalid_response':
              errorMessage = 'Risposta non valida dal server. Riprova più tardi.';
              break;
            case 'unknown_error':
              errorMessage = 'Errore durante la verifica. Riprova più tardi.';
              break;
            default:
              // Usa il messaggio dal backend se disponibile, altrimenti messaggio generico
              errorMessage = result.message ?? 'Verifica fallita. Riprova.';
          }
          
          _statusMessage = errorMessage;
        });
      }
    } catch (e) {
      // Gestione errori generici (non dovrebbe mai arrivare qui se il repository gestisce tutto)
      debugPrint('❌ [ERROR] Errore imprevisto durante verifica: $e');
      setState(() {
        _isVerifyingPairing = false;
        _lockerConnected = false;
        _lockerFound = false;
        _isScanning = false;
        
        // Messaggio user-friendly basato sul tipo di errore
        String errorMessage;
        if (e.toString().contains('ConnectionException') || 
            e.toString().contains('connessione') ||
            e.toString().contains('network')) {
          errorMessage = 'Errore di connessione. Verifica la tua connessione internet e riprova.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Timeout della richiesta. Riprova più tardi.';
        } else {
          errorMessage = 'Errore durante la verifica. Riprova più tardi.';
        }
        
        _statusMessage = errorMessage;
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
    // Verifica che l'accoppiamento sia stato verificato
    if (_pairingId == null || _activeCell == null) {
      setState(() {
        _statusMessage = 'Accoppiamento non verificato. Riprova.';
      });
      return;
    }
    
    final repository = AppDependencies.cellRepository;
    if (repository == null) {
      setState(() {
        _statusMessage = 'Servizio celle non disponibile.';
      });
      return;
    }

    try {
      setState(() {
        _statusMessage = 'Apertura cella in corso...';
      });
      
      // Usa pairingId per aprire la cella (backend verifica tutto)
      await repository.openCellWithPairing(
        pairingId: _pairingId!,
        cellId: _activeCell!.cellId,
        lockerId: widget.lockerId,
      );
      
      setState(() {
        _cellOpened = true;
        _waitingForDoorClose = true;
        _statusMessage = 'Cella aperta. Prendi l\'oggetto e chiudi lo sportello.';
      });

      // Timer per rilevare chiusura sportello
      // In produzione: il backend riceverà il segnale dal locker fisico e notificherà l'app
      _doorCloseTimer?.cancel();
      _doorCloseTimer = Timer(const Duration(seconds: 3), () {
        debugPrint('⏱️ [TIMER] Timer scaduto - chiusura rilevata');
        if (mounted && _waitingForDoorClose) {
          _handleDoorClosed();
        } else {
          debugPrint('⚠️ [TIMER] Widget non montato o non più in attesa');
        }
      });
      debugPrint('✅ [TIMER] Timer di 3 secondi avviato per rilevare chiusura');
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore nell\'apertura della cella: ${e.toString()}';
      });
    }
  }

  /// Gestisce la chiusura dello sportello
  /// 
  /// Viene chiamato quando il timer rileva la chiusura o quando il backend
  /// riceve il segnale di chiusura dal locker fisico (tramite sensore)
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
    
    // Cancella timer
    _doorCloseTimer?.cancel();
    _doorCloseTimer = null;
    
    setState(() {
      _waitingForDoorClose = false;
    });

    final activeCell = _activeCell ??
        ActiveCell(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          lockerId: widget.lockerId,
          lockerName: widget.lockerName,
          lockerType: 'Prestito',
          cellNumber: widget.cell.cellNumber,
          cellId: widget.cell.id,
          startTime: DateTime.now(),
          endTime: widget.cell.borrowDuration != null
              ? DateTime.now().add(widget.cell.borrowDuration!)
              : DateTime.now().add(const Duration(days: 7)),
          type: CellUsageType.borrowed,
        );
    
    debugPrint('📱 [CLOSE] Programmo promemoria per restituzione...');
    // Programma promemoria per restituire l'oggetto
    try {
      await NotificationService().scheduleBorrowReturnReminder(activeCell);
    } catch (e) {
      debugPrint('⚠️ [NOTIFICATION] Errore nella programmazione promemoria: $e');
    }

    debugPrint('📱 [CLOSE] Navigo alla schermata di conferma...');
    // Naviga alla schermata di conferma chiusura
    if (mounted) {
      try {
        await Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => _DoorClosedConfirmationPage(
              themeManager: widget.themeManager,
              cellNumber: widget.cell.cellNumber,
              lockerName: widget.lockerName,
              itemName: widget.cell.itemName ?? 'Oggetto',
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
              'Apri cella',
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
                  if (_waitingForDoorClose) ...[
                    // Schermata attesa chiusura sportello
                    _buildWaitingForCloseScreen(isDark),
                  ] else if (_lockerConnected && _cellOpened == false) ...[
                    // Se è per deposito, mostra schermata verifica completata
                    if (widget.onVerificationComplete != null)
                      _buildVerificationCompleteScreen(isDark)
                    else
                      // Schermata locker connesso - pulsante apri (per prestito)
                      _buildConnectedScreen(isDark),
                  ] else if (_isLoadingBluetoothInfo || _isVerifyingPairing) ...[
                    // Schermata caricamento info Bluetooth o verifica accoppiamento
                    _buildLoadingScreen(isDark),
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

  Widget _buildWaitingForCloseScreen(bool isDark) {
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
          'Prendi l\'oggetto in prestito',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Prendi l\'oggetto dalla cella. Ricorda di riportarlo entro la scadenza!',
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

  Widget _buildConnectedScreen(bool isDark) {
    final isReady = _activeCell != null;
    
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: isReady 
                ? AppColors.success(isDark).withOpacity(0.1)
                : AppColors.primary(isDark).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isReady 
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.hourglass,
            size: 60,
            color: isReady 
                ? AppColors.success(isDark)
                : AppColors.primary(isDark),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          isReady ? 'Locker connesso!' : 'Assegnazione cella...',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          isReady 
              ? 'Pronto per aprire la cella'
              : _statusMessage,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        if (isReady)
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
          )
        else
          const CupertinoActivityIndicator(radius: 20),
      ],
    );
  }
  
  Widget _buildLoadingScreen(bool isDark) {
    return Column(
      children: [
        const CupertinoActivityIndicator(radius: 20),
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
      ],
    );
  }

  Widget _buildVerificationCompleteScreen(bool isDark) {
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
          'Presenza verificata',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Procedendo al pagamento...',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        const CupertinoActivityIndicator(radius: 20),
      ],
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
        // Rimuoviamo il pulsante "Riprova" quando il locker è connesso
        if (!_isScanning && !_lockerFound && _isBluetoothEnabled && !_waitingForBluetoothActivation && !_lockerConnected) ...[
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              onPressed: _checkBluetoothAndStartScan,
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
}

/// Schermata di conferma chiusura sportello
class _DoorClosedConfirmationPage extends StatelessWidget {
  final ThemeManager themeManager;
  final String cellNumber;
  final String lockerName;
  final String itemName;

  const _DoorClosedConfirmationPage({
    required this.themeManager,
    required this.cellNumber,
    required this.lockerName,
    required this.itemName,
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
                    'Hai preso in prestito: $itemName',
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
                        // Torna alla home (pop fino alla home)
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

