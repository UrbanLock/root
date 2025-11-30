import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/notifications/notification_service.dart';
import 'package:app/features/cells/domain/models/active_cell.dart';

class OpenCellPage extends StatefulWidget {
  final ThemeManager themeManager;
  final ActiveCell cell; // Cella attiva
  final File? photo; // Foto se richiesta (per oggetti in prestito)
  final Function(String)? onCellClosed; // Callback quando la cella viene chiusa

  const OpenCellPage({
    super.key,
    required this.themeManager,
    required this.cell,
    this.photo,
    this.onCellClosed,
  });

  @override
  State<OpenCellPage> createState() => _OpenCellPageState();
}

class _OpenCellPageState extends State<OpenCellPage> {
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  bool _lockerFound = false;
  bool _cellOpened = false; // Indica se la cella è stata aperta
  bool _waitingForDoorClose = false; // Indica se stiamo aspettando la chiusura dello sportello
  String _statusMessage = 'Preparazione...';
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  @override
  void initState() {
    super.initState();
    _checkBluetoothAndStartScan();
  }

  @override
  void dispose() {
    _bluetoothStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _checkBluetoothAndStartScan() async {
    try {
      // Controlla se il Bluetooth è disponibile
      final adapterState = await FlutterBluePlus.adapterState.first;
      
      if (adapterState != BluetoothAdapterState.on) {
        setState(() {
          _isBluetoothEnabled = false;
          _statusMessage = 'Bluetooth non attivo';
        });
        _requestEnableBluetooth();
        return;
      }

      setState(() {
        _isBluetoothEnabled = true;
        _statusMessage = 'Ricerca locker in corso...';
        _isScanning = true;
      });

      // Ascolta i cambiamenti dello stato Bluetooth
      _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on && !_isScanning) {
          _startScan();
        } else if (state != BluetoothAdapterState.on) {
          setState(() {
            _isBluetoothEnabled = false;
            _isScanning = false;
            _statusMessage = 'Bluetooth non attivo';
          });
        }
      });

      // Avvia lo scan
      await _startScan();
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _requestEnableBluetooth() async {
    final isDark = widget.themeManager.isDarkMode;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Bluetooth richiesto'),
        content: const Text(
          'Per aprire la cella è necessario attivare il Bluetooth.\n\n'
          'Attiva il Bluetooth dalle impostazioni del dispositivo.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Annulla'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Impostazioni'),
            onPressed: () async {
              Navigator.of(context).pop();
              await FlutterBluePlus.turnOn();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startScan() async {
    try {
      // Genera un ID mock per il locker basato sul nome
      // In produzione, questo verrà dal backend
      final lockerDeviceId = _generateLockerDeviceId(widget.cell.lockerName);
      
      setState(() {
        _isScanning = true;
        _statusMessage = 'Ricerca locker in corso...';
        _lockerFound = false;
      });

      // Avvia lo scan
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      // Ascolta i risultati dello scan
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          // Controlla se il dispositivo trovato corrisponde al locker
          // In produzione, questo sarà basato su un UUID o nome specifico
          final deviceName = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.device.remoteId.toString();
          
          // Mock: simula il ritrovamento dopo 2-3 secondi
          // In produzione, verificheresti l'UUID o il nome del dispositivo
          if (!_lockerFound && _isScanning) {
            // Simula ritrovamento dopo un breve delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _isScanning) {
                setState(() {
                  _lockerFound = true;
                  _isScanning = false;
                  _statusMessage = 'Locker trovato!';
                });
                FlutterBluePlus.stopScan();
              }
            });
            break;
          }
        }
      });

      // Timeout dopo 10 secondi
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isScanning && !_lockerFound) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'Locker non trovato nelle vicinanze';
          });
          FlutterBluePlus.stopScan();
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Errore durante la ricerca: $e';
        _isScanning = false;
      });
    }
  }

  String _generateLockerDeviceId(String lockerName) {
    // Mock: genera un ID basato sul nome del locker
    // In produzione, questo verrà dal backend
    return 'LOCKER_${lockerName.replaceAll(' ', '_').toUpperCase()}';
  }

  Future<void> _openCell() async {
    // Simula l'apertura della cella
    setState(() {
      _cellOpened = true;
      _waitingForDoorClose = true;
      // Messaggio diverso in base al tipo:
      // - borrowed: rimetti l'oggetto (dopo averlo usato)
      // - deposited: preleva l'oggetto (deposito scaduto)
      // - pickup: ritira il prodotto
      if (widget.cell.type == CellUsageType.borrowed) {
        _statusMessage = 'Rimetti l\'oggetto nella cella';
      } else if (widget.cell.type == CellUsageType.deposited) {
        _statusMessage = 'Preleva l\'oggetto dalla cella';
      } else {
        _statusMessage = 'Ritira il prodotto dalla cella';
      }
    });

    // Notifica che la cella è stata aperta
    // Se l'app va in background, l'utente riceverà una notifica
    await NotificationService().notifyOpenCellInBackground(widget.cell);

    // Simula l'attesa del segnale dal backend che lo sportello è stato chiuso
    // In produzione, questo sarà un listener WebSocket o polling
    await _waitForDoorClose();
  }

  Future<void> _waitForDoorClose() async {
    // Simula l'attesa del segnale dal backend (3-5 secondi)
    // In produzione, questo sarà un listener reale
    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      // Lo sportello è stato chiuso, notifica l'utente
      await NotificationService().notifyCellClosed(widget.cell);
      
      // Lo sportello è stato chiuso, rimuovi la cella dalla lista
      widget.onCellClosed?.call(widget.cell.id);
      
      // Torna indietro alla schermata precedente
      Navigator.of(context).pop();
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
                  // Mostra schermata di attesa chiusura sportello se la cella è stata aperta
                  if (_waitingForDoorClose) ...[
                    // Icona sportello
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.lock,
                        size: 60,
                        color: AppColors.primary(isDark),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Messaggio principale
                    Text(
                      widget.cell.type == CellUsageType.borrowed
                          ? 'Rimetti l\'oggetto nella cella'
                          : widget.cell.type == CellUsageType.deposited
                              ? 'Preleva l\'oggetto dalla cella'
                              : 'Ritira il prodotto dalla cella',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(isDark),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Istruzioni
                    Text(
                      widget.cell.type == CellUsageType.borrowed
                          ? 'Inserisci l\'oggetto nella cella e chiudi lo sportello'
                          : widget.cell.type == CellUsageType.deposited
                              ? 'Preleva l\'oggetto dalla cella e chiudi lo sportello'
                              : 'Ritira il prodotto dalla cella e chiudi lo sportello',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary(isDark),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // Indicatore di attesa
                    Column(
                      children: [
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
                    ),
                  ] else ...[
                    // Schermata Bluetooth (quando non stiamo aspettando la chiusura)
                    // Icona Bluetooth
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
                    // Messaggio di stato
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
                    // Descrizione
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
                    // Indicatore di ricerca
                    if (_isScanning)
                      Column(
                        children: [
                          const CupertinoActivityIndicator(radius: 20),
                          const SizedBox(height: 16),
                          Text(
                            'Ricerca in corso...',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    // Pulsante apri (solo quando il locker è trovato)
                    if (_lockerFound) ...[
                      const SizedBox(height: 20),
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
                    // Pulsante riprova (se non trovato)
                    if (!_isScanning && !_lockerFound && _isBluetoothEnabled) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          color: AppColors.surface(isDark),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
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
                  // Info locker
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

