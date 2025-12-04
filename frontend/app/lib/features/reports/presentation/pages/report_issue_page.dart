import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

/// Pagina per segnalare un problema con il locker o la cella
/// 
/// Permette all'utente di:
/// - Selezionare una categoria del problema
/// - Aggiungere una descrizione
/// - Scattare/aggiungere una foto
/// - Inviare la segnalazione al backend
/// 
/// **TODO quando il backend sarà pronto:**
/// - POST /api/v1/reports con: lockerId, cellId, category, description, photo, userId
class ReportIssuePage extends StatefulWidget {
  final ThemeManager themeManager;
  final String? lockerId;
  final String? lockerName;
  final String? cellId;
  final String? cellNumber;
  final String? reportId; // ID della segnalazione da modificare
  final Map<String, dynamic>? existingReport; // Dati esistenti per la modifica

  const ReportIssuePage({
    super.key,
    required this.themeManager,
    this.lockerId,
    this.lockerName,
    this.cellId,
    this.cellNumber,
    this.reportId,
    this.existingReport,
  });

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  
  File? _photoFile;
  String? _selectedCategory;
  bool _isSubmitting = false;

  // Categorie di problemi
  final List<Map<String, String>> _categories = [
    {'id': 'cell_not_opening', 'label': 'Cella non si apre'},
    {'id': 'cell_not_closing', 'label': 'Cella non si chiude'},
    {'id': 'bluetooth_connection', 'label': 'Problema connessione Bluetooth'},
    {'id': 'damaged_cell', 'label': 'Cella danneggiata'},
    {'id': 'damaged_locker', 'label': 'Locker danneggiato'},
    {'id': 'other', 'label': 'Altro'},
  ];

  @override
  void initState() {
    super.initState();
    // Se si sta modificando, pre-compila i campi
    if (widget.existingReport != null) {
      final report = widget.existingReport!;
      _descriptionController.text = report['description'] as String? ?? '';
      
      // Mappa la categoria dal label all'id
      final categoryLabel = report['category'] as String? ?? '';
      final categoryMap = {
        'Cella non si apre': 'cell_not_opening',
        'Cella non si chiude': 'cell_not_closing',
        'Problema connessione Bluetooth': 'bluetooth_connection',
        'Cella danneggiata': 'damaged_cell',
        'Locker danneggiato': 'damaged_locker',
        'Altro': 'other',
      };
      _selectedCategory = categoryMap[categoryLabel];
      
      // Se la categoria non è stata trovata, prova a usare direttamente il valore
      if (_selectedCategory == null) {
        // Cerca nell'elenco delle categorie per trovare quella corrispondente
        for (var cat in _categories) {
          if (cat['label'] == categoryLabel) {
            _selectedCategory = cat['id'];
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Richiede una foto dalla fotocamera
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _photoFile = File(photo.path);
        });
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Errore'),
            content: Text('Impossibile scattare la foto: $e'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Rimuove la foto selezionata
  void _removePhoto() {
    setState(() {
      _photoFile = null;
    });
  }

  /// Invia la segnalazione
  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Attenzione'),
          content: const Text('Seleziona una categoria per il problema.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Attenzione'),
          content: const Text('Inserisci una descrizione del problema.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // ⚠️ SOLO PER TESTING: Simula invio segnalazione
    // IN PRODUZIONE: Inviare al backend
    // POST /api/v1/reports
    // {
    //   "lockerId": widget.lockerId,
    //   "cellId": widget.cellId,
    //   "category": _selectedCategory,
    //   "description": _descriptionController.text,
    //   "photo": base64(_photoFile) se presente,
    //   "userId": currentUserId
    // }
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(widget.existingReport != null
              ? 'Segnalazione modificata'
              : 'Segnalazione inviata'),
          content: Text(widget.existingReport != null
              ? 'Le modifiche alla segnalazione sono state salvate con successo.'
              : 'La tua segnalazione è stata inviata con successo. Ti contatteremo a breve.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop(); // Chiudi dialog
                Navigator.of(context).pop(true); // Torna alla pagina precedente con risultato
              },
              child: const Text('OK'),
            ),
          ],
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
              widget.existingReport != null
                  ? 'Modifica segnalazione'
                  : 'Segnala problema',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: _isSubmitting
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CupertinoActivityIndicator(radius: 20),
                        const SizedBox(height: 16),
                        Text(
                          'Invio segnalazione...',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info locker (solo se presente)
                        if (widget.lockerName != null) ...[
                          Container(
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
                                      CupertinoIcons.location_solid,
                                      size: 16,
                                      color: AppColors.textSecondary(isDark),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.lockerName!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.text(isDark),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.cellNumber != null) ...[
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
                                        'Cella ${widget.cellNumber}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        
                        // Categoria
                        Text(
                          'Categoria problema *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(isDark),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._categories.map((category) {
                          final isSelected = _selectedCategory == category['id'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _selectedCategory = category['id'];
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary(isDark).withOpacity(0.1)
                                      : AppColors.surface(isDark),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary(isDark)
                                        : AppColors.borderColor(isDark),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? CupertinoIcons.check_mark_circled_solid
                                          : CupertinoIcons.circle,
                                      color: isSelected
                                          ? AppColors.primary(isDark)
                                          : AppColors.textSecondary(isDark),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      category['label']!,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: AppColors.text(isDark),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 32),
                        
                        // Descrizione
                        Text(
                          'Descrizione *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(isDark),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface(isDark),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.borderColor(isDark),
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: _descriptionController,
                            placeholder: 'Descrivi il problema in dettaglio...',
                            placeholderStyle: TextStyle(
                              color: AppColors.textSecondary(isDark),
                            ),
                            style: TextStyle(
                              color: AppColors.text(isDark),
                            ),
                            padding: const EdgeInsets.all(16),
                            maxLines: 6,
                            decoration: const BoxDecoration(),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Foto
                        Text(
                          'Foto (opzionale)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(isDark),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_photoFile == null)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _takePhoto,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface(isDark),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderColor(isDark),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    CupertinoIcons.camera,
                                    size: 40,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Scatta foto',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textSecondary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.borderColor(isDark),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _photoFile!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minSize: 0,
                                  onPressed: _removePhoto,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface(isDark).withOpacity(0.9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.xmark,
                                      size: 20,
                                      color: CupertinoColors.destructiveRed,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 40),
                        
                        // Pulsante invio
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            borderRadius: BorderRadius.circular(12),
                            onPressed: _submitReport,
                            child: Text(
                              widget.existingReport != null
                                  ? 'Salva modifiche'
                                  : 'Invia segnalazione',
                              style: const TextStyle(
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


