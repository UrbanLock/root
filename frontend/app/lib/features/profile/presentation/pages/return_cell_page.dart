import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';
import 'package:app/features/cells/data/repositories/cell_repository_mock.dart';
import 'package:app/features/reports/presentation/pages/report_issue_page.dart';

/// Pagina per restituire un oggetto preso in prestito
/// 
/// **Flusso:**
/// 1. Richiesta foto dell'oggetto per verifica condizioni
/// 2. Anteprima foto e conferma
/// 3. Ricerca del locker via Bluetooth
/// 4. Se Bluetooth non attivo, richiesta attivazione con refresh automatico
/// 5. Una volta connesso, pulsante per aprire la cella
/// 6. L'utente mette l'oggetto dentro
/// 7. Attesa chiusura sportello (simulata con 3 secondi)
/// 8. Schermata di conferma chiusura e rimozione dalla lista attive
/// 
/// **TODO quando il backend sarà pronto:**
/// - Upload foto al backend (POST /api/v1/cells/return/photo)
/// - UUID reale del locker dal backend
/// - Comando Bluetooth reale per aprire la cella
/// - Rilevamento chiusura tramite sensore/signale Bluetooth
/// - Notifica backend della restituzione (POST /api/v1/cells/return)
class ReturnCellPage extends StatefulWidget {
  final ThemeManager themeManager;
  final ActiveCell cell;

  const ReturnCellPage({
    super.key,
    required this.themeManager,
    required this.cell,
  });

  @override
  State<ReturnCellPage> createState() => _ReturnCellPageState();
}

class _ReturnCellPageState extends State<ReturnCellPage> {
  // Stati foto
  File? _photoFile;
  bool _photoTaken = false;
  bool _photoConfirmed = false;
  String? _photoBase64; // Base64 della foto per il backend
  
  // Stati Bluetooth
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  bool _lockerFound = false;
  bool _lockerConnected = false;
  bool _waitingForBluetoothActivation = false;
  String _statusMessage = 'Preparazione...';
  
  // Stati apertura/chiusura cella
  bool _cellOpened = false;
  bool _waitingForDoorClose = false;
  
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  Timer? _doorCloseTimer;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _doorCloseTimer?.cancel();
    _bluetoothStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  /// Richiede all'utente di scattare una foto
  Future<void> _requestPhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      
      if (photo != null) {
        setState(() {
          _photoFile = File(photo.path);
          _photoTaken = true;
          _photoConfirmed = false;
        });
        
        // TODO BACKEND: Converti in base64 per inviare al backend
        // final bytes = await photo.readAsBytes();
        // _photoBase64 = base64Encode(bytes);
      }
    } catch (e) {
      debugPrint('⚠️ [PHOTO] Errore nella selezione foto: $e');
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

  /// Conferma la foto e procede con la ricerca Bluetooth
  void _confirmPhoto() {
    setState(() {
      _photoConfirmed = true;
    });
    
    // Avvia la ricerca Bluetooth dopo la conferma
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkBluetoothAndStartScan();
    });
  }

  /// Scatta una nuova foto
  void _retakePhoto() {
    setState(() {
      _photoTaken = false;
      _photoFile = null;
      _photoConfirmed = false;
    });
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
      
      _startScan();
    } catch (e) {
      debugPrint('⚠️ [BLUETOOTH] Errore: $e');
      setState(() {
        _statusMessage = 'Errore: $e';
      });
    }
  }

  /// Imposta il listener per lo stato Bluetooth
  void _setupBluetoothListener() {
    _bluetoothStateSubscription?.cancel();
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      debugPrint('📡 [BLUETOOTH] Stato cambiato: $state');
      if (state == BluetoothAdapterState.on && _waitingForBluetoothActivation) {
        setState(() {
          _waitingForBluetoothActivation = false;
          _isBluetoothEnabled = true;
        });
        _startScan();
      }
    });
  }

  /// Richiede l'attivazione del Bluetooth
  Future<void> _requestEnableBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      debugPrint('⚠️ [BLUETOOTH] Errore attivazione: $e');
    }
  }

  /// Avvia la scansione Bluetooth
  Future<void> _startScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _statusMessage = 'Ricerca locker in corso...';
      _lockerFound = false;
      _lockerConnected = false;
    });

    try {
      // TODO BACKEND: Usa UUID reale del locker
      // final lockerUuid = await getLockerUuid(widget.cell.lockerId);
      
      // ⚠️ SOLO PER TESTING: Simula ricerca e connessione
      await Future.delayed(const Duration(seconds: 2));
      
      // Simula scoperta del locker
      setState(() {
        _lockerFound = true;
        _lockerConnected = true;
        _isScanning = false;
        _statusMessage = 'Locker connesso';
      });
    } catch (e) {
      debugPrint('⚠️ [SCAN] Errore: $e');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Errore nella ricerca';
      });
    }
  }

  /// Gestisce la segnalazione di un problema
  void _handleReport() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ReportIssuePage(
          themeManager: widget.themeManager,
          lockerId: widget.cell.lockerId,
          lockerName: widget.cell.lockerName,
          cellId: widget.cell.cellId,
          cellNumber: widget.cell.cellNumber,
        ),
      ),
    );
  }

  /// Apre la cella
  Future<void> _openCell() async {
    if (!_lockerConnected) return;
    
    setState(() {
      _cellOpened = true;
      _waitingForDoorClose = true; // Vai direttamente alla schermata di attesa chiusura
      _statusMessage = 'In attesa della chiusura dello sportello';
    });
    
    // TODO BACKEND: Invia comando Bluetooth per aprire la cella
    // await sendOpenCellCommand(widget.cell.cellId);
    
    // ⚠️ SOLO PER TESTING: Simula apertura (rimosso delay per evitare schermata intermedia)
    
    // Dopo 3 secondi, simula chiusura
    _doorCloseTimer = Timer(const Duration(seconds: 3), () {
      _handleDoorClosed();
    });
  }

  /// Gestisce la chiusura dello sportello
  Future<void> _handleDoorClosed() async {
    if (!mounted || !_waitingForDoorClose) return;
    
    _doorCloseTimer?.cancel();
    _doorCloseTimer = null;

    // TODO BACKEND: Notifica restituzione al backend
    // POST /api/v1/cells/return
    // Body: { cell_id, photo_base64 }
    final repository = AppDependencies.cellRepository;
    if (repository != null) {
      try {
        await repository.notifyCellClosed(widget.cell.cellId);
      } catch (e) {
        debugPrint('⚠️ [RETURN] Errore notifica backend: $e');
      }
    }

    // Naviga direttamente alla schermata di conferma senza cambiare lo stato
    // per evitare schermate intermedie
    if (mounted) {
      try {
        await Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => _ReturnConfirmationPage(
              themeManager: widget.themeManager,
              cellNumber: widget.cell.cellNumber,
              lockerName: widget.cell.lockerName,
            ),
          ),
        );
      } catch (e) {
        debugPrint('❌ [RETURN] Errore durante navigazione: $e');
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
              'Restituisci oggetto',
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
                  if (!_photoTaken) ...[
                    // Richiesta foto
                    _buildPhotoRequestScreen(isDark),
                  ] else if (!_photoConfirmed) ...[
                    // Anteprima foto e conferma
                    _buildPhotoPreviewScreen(isDark),
                  ] else if (_cellOpened && _waitingForDoorClose) ...[
                    // Schermata attesa chiusura sportello
                    _buildWaitingForCloseScreen(isDark),
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

  Widget _buildPhotoRequestScreen(bool isDark) {
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
            CupertinoIcons.camera_fill,
            size: 60,
            color: AppColors.primary(isDark),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Scatta una foto',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Scatta una foto dell\'oggetto per verificare le condizioni prima della restituzione',
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
            onPressed: _requestPhoto,
            child: const Text(
              'Scatta foto',
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

  Widget _buildPhotoPreviewScreen(bool isDark) {
    return Column(
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.borderColor(isDark),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _photoFile != null
                ? Image.file(
                    _photoFile!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: AppColors.surface(isDark),
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 60,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Anteprima foto',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Verifica che la foto sia chiara e mostri l\'oggetto correttamente',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
                onPressed: _retakePhoto,
                child: Text(
                  'Riscatta',
                  style: TextStyle(
                    color: AppColors.text(isDark),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 16),
                borderRadius: BorderRadius.circular(12),
                onPressed: _confirmPhoto,
                child: const Text(
                  'Conferma',
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
          'In attesa della chiusura dello sportello',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Chiudi correttamente lo sportello della cella',
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
          'In attesa della chiusura...',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(isDark),
          ),
          textAlign: TextAlign.center,
        ),
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
                  widget.cell.lockerName,
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

/// Pagina di conferma restituzione
class _ReturnConfirmationPage extends StatelessWidget {
  final ThemeManager themeManager;
  final String cellNumber;
  final String lockerName;

  const _ReturnConfirmationPage({
    required this.themeManager,
    required this.cellNumber,
    required this.lockerName,
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
              'Restituzione completata',
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
                    'L\'oggetto è stato restituito con successo',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
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
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () {
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
