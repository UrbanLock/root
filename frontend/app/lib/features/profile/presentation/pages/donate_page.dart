import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class DonatePage extends StatelessWidget {
  final ThemeManager themeManager;

  const DonatePage({
    super.key,
    required this.themeManager,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeManager.isDarkMode;

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
                  Text(
                    'Cosa vuoi donare?',
                    style: AppTextStyles.body(isDark),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
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
                      ),
                      _buildCategoryChip(
                        isDark: isDark,
                        label: 'Libri',
                        icon: CupertinoIcons.book,
                      ),
                      _buildCategoryChip(
                        isDark: isDark,
                        label: 'Giochi',
                        icon: CupertinoIcons.game_controller,
                      ),
                      _buildCategoryChip(
                        isDark: isDark,
                        label: 'Altro',
                        icon: CupertinoIcons.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () {
                        // TODO: Invia donazione
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
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text(
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
  }

  Widget _buildCategoryChip({
    required bool isDark,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderColor(isDark),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.primary(isDark),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

