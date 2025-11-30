import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class DonatePage extends StatefulWidget {
  final ThemeManager themeManager;

  const DonatePage({
    super.key,
    required this.themeManager,
  });

  @override
  State<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _selectedCategory;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _itemController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
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
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  void _submitDonation() {
    final isDark = widget.themeManager.isDarkMode;

    // Validazione: foto obbligatoria
    if (_selectedImage == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Foto richiesta'),
          content: const Text(
            'È obbligatorio scattare una foto all\'oggetto che vuoi donare.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    // Validazione: nome oggetto
    if (_itemController.text.trim().isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Campo obbligatorio'),
          content: const Text('Inserisci il nome dell\'oggetto che vuoi donare.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simula invio (TODO: implementare chiamata API)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Donazione inviata'),
            content: const Text(
              'La tua donazione è stata registrata. Verrà esaminata e pubblicata a breve.',
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
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
              'Donare un oggetto',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // Header informativo
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.gift_fill,
                        size: 48,
                        color: AppColors.primary(isDark),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Condividi con la comunità',
                        style: AppTextStyles.title(isDark),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dona oggetti utili che altri possono utilizzare. Contribuisci a rendere Trento più sostenibile.',
                        style: AppTextStyles.bodySecondary(isDark),
                      ),
                    ],
                  ),
                ),
                // Form donazione
                Container(
                  color: AppColors.surface(isDark),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Foto obbligatoria
                      Text(
                        'Foto dell\'oggetto *',
                        style: AppTextStyles.body(isDark),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scatta una foto all\'oggetto che vuoi donare',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _takePhoto,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppColors.background(isDark),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedImage == null
                                  ? CupertinoColors.systemRed
                                  : AppColors.borderColor(isDark),
                              width: _selectedImage == null ? 2 : 1,
                            ),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.camera_fill,
                                      size: 48,
                                      color: _selectedImage == null
                                          ? CupertinoColors.systemRed
                                          : AppColors.textSecondary(isDark),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tocca per scattare una foto',
                                      style: TextStyle(
                                        color: _selectedImage == null
                                            ? CupertinoColors.systemRed
                                            : AppColors.textSecondary(isDark),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_selectedImage == null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Obbligatorio',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors.systemRed,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Cosa vuoi donare? *',
                        style: AppTextStyles.body(isDark),
                      ),
                      const SizedBox(height: 12),
                      CupertinoTextField(
                        controller: _itemController,
                        placeholder: 'Es. Attrezzatura sportiva, libri, giochi...',
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background(isDark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderColor(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Descrizione',
                        style: AppTextStyles.body(isDark),
                      ),
                      const SizedBox(height: 12),
                      CupertinoTextField(
                        controller: _descriptionController,
                        placeholder: 'Descrivi l\'oggetto e le sue condizioni...',
                        maxLines: 4,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background(isDark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderColor(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Seleziona categoria',
                        style: AppTextStyles.body(isDark),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCategoryChip(
                            isDark: isDark,
                            label: 'Sport',
                            icon: CupertinoIcons.sportscourt,
                            isSelected: _selectedCategory == 'Sport',
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'Sport';
                              });
                            },
                          ),
                          _buildCategoryChip(
                            isDark: isDark,
                            label: 'Libri',
                            icon: CupertinoIcons.book,
                            isSelected: _selectedCategory == 'Libri',
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'Libri';
                              });
                            },
                          ),
                          _buildCategoryChip(
                            isDark: isDark,
                            label: 'Giochi',
                            icon: CupertinoIcons.game_controller,
                            isSelected: _selectedCategory == 'Giochi',
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'Giochi';
                              });
                            },
                          ),
                          _buildCategoryChip(
                            isDark: isDark,
                            label: 'Altro',
                            icon: CupertinoIcons.ellipsis,
                            isSelected: _selectedCategory == 'Altro',
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'Altro';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _isSubmitting ? null : _submitDonation,
                          child: _isSubmitting
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                )
                              : const Text(
                                  'Invia donazione',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary(isDark).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.info_circle,
                          color: AppColors.primary(isDark),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gli oggetti donati saranno disponibili per tutti gli utenti della comunità.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.text(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip({
    required bool isDark,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary(isDark).withOpacity(0.2)
              : AppColors.background(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary(isDark)
                : AppColors.borderColor(isDark),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primary(isDark)
                  : AppColors.textSecondary(isDark),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? AppColors.primary(isDark)
                    : AppColors.text(isDark),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
