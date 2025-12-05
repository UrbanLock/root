import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/lockers/domain/models/locker_cell.dart';
import 'package:app/features/payment/presentation/pages/deposit_open_cell_page.dart';
import 'package:app/core/notifications/notification_service.dart';

/// Pagina di pagamento per affittare una cella di deposito
/// 
/// **Flusso:**
/// 1. Mostra dettagli cella e costo
/// 2. Simula pagamento (mock per testing)
/// 3. Dopo pagamento, naviga alla pagina di apertura cella
/// 
/// **TODO quando il backend sarà pronto:**
/// - Integrazione con gateway di pagamento reale (Stripe, PayPal, ecc.)
/// - Chiamata API per processare il pagamento (POST /api/v1/payments)
/// - Gestione metodi di pagamento salvati
/// - Ricevuta di pagamento
class DepositPaymentPage extends StatefulWidget {
  final ThemeManager themeManager;
  final LockerCell cell;
  final String lockerName;
  final String lockerId;

  const DepositPaymentPage({
    super.key,
    required this.themeManager,
    required this.cell,
    required this.lockerName,
    required this.lockerId,
  });

  @override
  State<DepositPaymentPage> createState() => _DepositPaymentPageState();
}

class _DepositPaymentPageState extends State<DepositPaymentPage> {
  // Selezione durata
  int _selectedHours = 1; // Default 1 giorno
  bool _useDays = true; // true = giorni, false = ore
  
  // Stati pagamento
  bool _isProcessing = false;
  bool _paymentSuccess = false;
  bool _paymentFailed = false;
  String? _paymentError;
  
  // Stati Bluetooth (verifica silenziosa)
  bool _isVerifyingBluetooth = false;
  bool _isBluetoothConnected = false;
  bool _isBluetoothEnabled = false;
  bool _bluetoothCheckComplete = false;
  
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  /// Calcola il prezzo totale in base alla durata selezionata
  double _calculateTotalPrice() {
    if (_useDays) {
      return widget.cell.pricePerDay * _selectedHours;
    } else {
      return widget.cell.pricePerHour * _selectedHours;
    }
  }

  /// Calcola la durata in ore
  Duration _getSelectedDuration() {
    return Duration(hours: _selectedHours);
  }

  /// Simula il pagamento
  /// 
  /// **TODO BACKEND**: Sostituire con chiamata API reale
  /// POST /api/v1/payments
  /// Body: { cellId, lockerId, amount, paymentMethod, duration }
  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _paymentSuccess = false;
      _paymentFailed = false;
      _paymentError = null;
    });

    // ⚠️ SOLO PER TESTING: Simula pagamento con delay di 2 secondi
    // IN PRODUZIONE: Chiamata API al backend per processare il pagamento
    await Future.delayed(const Duration(seconds: 2));

    // TODO BACKEND: Verificare risposta dal backend
    // if (response.success) {
    //   setState(() { _paymentSuccess = true; });
    // } else {
    //   setState() { _paymentFailed = true; _paymentError = response.error; });
    // }

    // Simula successo (per testing)
    setState(() {
      _isProcessing = false;
      _paymentSuccess = true;
      // Inizializza i flag Bluetooth
      _isVerifyingBluetooth = false;
      _bluetoothCheckComplete = false;
    });


    // Dopo il pagamento, verifica silenziosamente la connessione Bluetooth
    // Usa un piccolo delay per assicurarsi che lo stato sia aggiornato
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _verifyBluetoothConnectionSilently();
      }
    });
  }

  @override
  void dispose() {
    _bluetoothStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  /// Verifica silenziosamente la connessione Bluetooth al locker
  /// (senza mostrare messaggi all'utente)
  Future<void> _verifyBluetoothConnectionSilently() async {
    setState(() {
      _isVerifyingBluetooth = true;
      _bluetoothCheckComplete = false;
    });

    try {
      // Verifica se Bluetooth è attivo
      final adapterState = await FlutterBluePlus.adapterState.first;
      
      if (adapterState != BluetoothAdapterState.on) {
        setState(() {
          _isBluetoothEnabled = false;
          _isBluetoothConnected = false;
          _isVerifyingBluetooth = false;
          _bluetoothCheckComplete = true;
        });
        return;
      }

      setState(() {
        _isBluetoothEnabled = true;
      });

      // Avvia la ricerca del locker
      await _startBluetoothScan();
    } catch (e) {
      debugPrint('❌ [BLUETOOTH] Errore verifica: $e');
      setState(() {
        _isBluetoothConnected = false;
        _isVerifyingBluetooth = false;
        _bluetoothCheckComplete = true;
      });
    }
  }

  /// Imposta il listener per i cambiamenti dello stato Bluetooth
  void _setupBluetoothListener() {
    _bluetoothStateSubscription?.cancel();
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        setState(() {
          _isBluetoothEnabled = true;
        });
        if (!_isBluetoothConnected) {
          _startBluetoothScan();
        }
      } else {
        setState(() {
          _isBluetoothEnabled = false;
          _isBluetoothConnected = false;
        });
      }
    });
  }

  /// Avvia la scansione Bluetooth per verificare la connessione
  Future<void> _startBluetoothScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        // ⚠️ SOLO PER TESTING: Simula ritrovamento dopo 2 secondi
        // IN PRODUZIONE: Verificare UUID del locker
        if (!_isBluetoothConnected && _isVerifyingBluetooth) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isBluetoothConnected) {
              setState(() {
                _isBluetoothConnected = true;
                _isVerifyingBluetooth = false;
                _bluetoothCheckComplete = true;
              });
              FlutterBluePlus.stopScan();
            }
          });
        }
      });

      // Timeout dopo 10 secondi
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && !_isBluetoothConnected && _isVerifyingBluetooth) {
          setState(() {
            _isBluetoothConnected = false;
            _isVerifyingBluetooth = false;
            _bluetoothCheckComplete = true;
          });
          FlutterBluePlus.stopScan();
        }
      });
    } catch (e) {
      debugPrint('❌ [BLUETOOTH] Errore scansione: $e');
      setState(() {
        _isBluetoothConnected = false;
        _isVerifyingBluetooth = false;
        _bluetoothCheckComplete = true;
      });
    }
  }

  /// Naviga alla pagina di apertura cella
  void _openCell() {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (context) => DepositOpenCellPage(
          themeManager: widget.themeManager,
          cell: widget.cell,
          lockerName: widget.lockerName,
          lockerId: widget.lockerId,
          duration: _getSelectedDuration(), // Passa la durata selezionata
          skipBluetoothVerification: true, // Salta verifica Bluetooth (già verificata)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeManager,
      builder: (context, _) {
        final isDark = widget.themeManager.isDarkMode;
        final pricePerDay = widget.cell.pricePerDay;
        final pricePerHour = widget.cell.pricePerHour;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: const Text('Pagamento'),
          ),
          child: SafeArea(
            child: _isProcessing
                ? _buildProcessingScreen(isDark)
                : _paymentSuccess
                    ? _buildPaymentConfirmationScreen(isDark)
                    : _paymentFailed
                        ? _buildPaymentErrorScreen(isDark)
                        : _buildPaymentScreen(isDark, pricePerDay, pricePerHour),
          ),
        );
      },
    );
  }

  Widget _buildPaymentScreen(bool isDark, double pricePerDay, double pricePerHour) {
    final totalPrice = _calculateTotalPrice();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con info cella
          _buildCellInfoCard(isDark),
          const SizedBox(height: 24),
          
          // Selezione durata
          _buildDurationSelection(isDark, pricePerDay, pricePerHour),
          const SizedBox(height: 24),
          
          // Riepilogo costi
          _buildCostSummary(isDark, totalPrice),
          const SizedBox(height: 24),
          
          // Metodo di pagamento (mock)
          _buildPaymentMethodCard(isDark),
          const SizedBox(height: 32),
          
          // Pulsante paga
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 16),
              borderRadius: BorderRadius.circular(12),
              onPressed: _isProcessing ? null : _processPayment,
              child: Text(
                'Paga €${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.info,
                  size: 16,
                  color: AppColors.textSecondary(isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ SOLO PER TESTING: Il pagamento è simulato. In produzione verrà integrato un gateway di pagamento reale.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
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
                widget.cell.cellNumber,
                style: AppTextStyles.title(isDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.square_grid_2x2,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.cell.size.label} (${widget.cell.size.dimensions})',
                style: AppTextStyles.body(isDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  widget.lockerName,
                  style: AppTextStyles.bodySecondary(isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelection(bool isDark, double pricePerDay, double pricePerHour) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Durata affitto',
            style: AppTextStyles.title(isDark),
          ),
          const SizedBox(height: 16),
          // Toggle giorni/ore
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: _useDays ? AppColors.primary(isDark) : AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () {
                    setState(() {
                      _useDays = true;
                      _selectedHours = 1; // Reset a 1 giorno
                    });
                  },
                  child: Text(
                    'Giorni',
                    style: TextStyle(
                      color: _useDays ? CupertinoColors.white : AppColors.text(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: !_useDays ? AppColors.primary(isDark) : AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () {
                    setState(() {
                      _useDays = false;
                      _selectedHours = 1; // Reset a 1 ora
                    });
                  },
                  child: Text(
                    'Ore',
                    style: TextStyle(
                      color: !_useDays ? CupertinoColors.white : AppColors.text(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Selezione quantità
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Durata:',
                style: AppTextStyles.body(isDark),
              ),
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: _selectedHours > 1
                        ? () {
                            setState(() {
                              _selectedHours--;
                            });
                          }
                        : null,
                    child: Icon(
                      CupertinoIcons.minus_circle,
                      color: _selectedHours > 1
                          ? AppColors.primary(isDark)
                          : AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _useDays
                        ? '$_selectedHours ${_selectedHours == 1 ? 'giorno' : 'giorni'}'
                        : '$_selectedHours ${_selectedHours == 1 ? 'ora' : 'ore'}',
                    style: AppTextStyles.title(isDark).copyWith(fontSize: 18),
                  ),
                  const SizedBox(width: 16),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: _selectedHours < (_useDays ? 30 : 168) // Max 30 giorni o 168 ore (7 giorni)
                        ? () {
                            setState(() {
                              _selectedHours++;
                            });
                          }
                        : null,
                    child: Icon(
                      CupertinoIcons.plus_circle,
                      color: _selectedHours < (_useDays ? 30 : 168)
                          ? AppColors.primary(isDark)
                          : AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _useDays
                ? '€${pricePerDay.toStringAsFixed(2)}/giorno'
                : '€${pricePerHour.toStringAsFixed(2)}/ora',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostSummary(bool isDark, double totalPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Riepilogo',
            style: AppTextStyles.title(isDark),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _useDays
                    ? 'Affitto $_selectedHours ${_selectedHours == 1 ? 'giorno' : 'giorni'}'
                    : 'Affitto $_selectedHours ${_selectedHours == 1 ? 'ora' : 'ore'}',
                style: AppTextStyles.body(isDark),
              ),
              Text(
                '€${totalPrice.toStringAsFixed(2)}',
                style: AppTextStyles.body(isDark).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(
            height: 1,
            color: AppColors.borderColor(isDark).withOpacity(0.1),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Totale',
                style: AppTextStyles.title(isDark),
              ),
              Text(
                '€${totalPrice.toStringAsFixed(2)}',
                style: AppTextStyles.title(isDark).copyWith(
                  color: AppColors.primary(isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metodo di pagamento',
            style: AppTextStyles.title(isDark),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.creditcard,
                size: 20,
                color: AppColors.primary(isDark),
              ),
              const SizedBox(width: 12),
              Text(
                'Carta di credito •••• 1234',
                style: AppTextStyles.body(isDark),
              ),
              const Spacer(),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ SOLO PER TESTING: Metodo di pagamento mock',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 20),
            const SizedBox(height: 24),
            Text(
              'Elaborazione pagamento...',
              style: AppTextStyles.title(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Attendere prego',
              style: AppTextStyles.bodySecondary(isDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentConfirmationScreen(bool isDark) {
    // Aspetta che la verifica Bluetooth sia completata prima di mostrare il pulsante
    // Se sta ancora verificando, mostra un breve messaggio
    if (_isVerifyingBluetooth || !_bluetoothCheckComplete) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.check_mark_circled,
                size: 80,
                color: AppColors.success(isDark),
              ),
              const SizedBox(height: 24),
              Text(
                'Pagamento effettuato con successo',
                style: AppTextStyles.title(isDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const CupertinoActivityIndicator(radius: 16),
              const SizedBox(height: 12),
              Text(
                'Verifica connessione...',
                style: AppTextStyles.bodySecondary(isDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Se Bluetooth non è connesso, mostra messaggio
    if (!_isBluetoothConnected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 80,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(height: 24),
              Text(
                'Locker non raggiungibile',
                style: AppTextStyles.title(isDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Assicurati di essere vicino al locker per aprire la cella',
                style: AppTextStyles.bodySecondary(isDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () {
                  _verifyBluetoothConnectionSilently();
                },
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    // Bluetooth connesso, mostra pulsante per aprire cella
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.check_mark_circled,
              size: 80,
              color: AppColors.success(isDark),
            ),
            const SizedBox(height: 24),
            Text(
              'Pagamento effettuato con successo',
              style: AppTextStyles.title(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Pronto per aprire la cella',
              style: AppTextStyles.bodySecondary(isDark),
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
        ),
      ),
    );
  }

  Widget _buildPaymentErrorScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.xmark_circle,
              size: 80,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 24),
            Text(
              'Pagamento fallito',
              style: AppTextStyles.title(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _paymentError ?? 'Si è verificato un errore durante il pagamento',
              style: AppTextStyles.bodySecondary(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () {
                setState(() {
                  _paymentFailed = false;
                  _paymentError = null;
                });
              },
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

