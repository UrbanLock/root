import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

/// Pagina per la gestione della privacy
class PrivacyPage extends StatelessWidget {
  final ThemeManager themeManager;

  const PrivacyPage({
    super.key,
    required this.themeManager,
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
              'Privacy',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.lock_fill,
                          size: 48,
                          color: AppColors.primary(isDark),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Gestisci la tua privacy',
                          style: AppTextStyles.title(isDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Controlla come vengono utilizzati i tuoi dati personali.',
                          style: AppTextStyles.bodySecondary(isDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Impostazioni privacy
                  Text(
                    'IMPOSTAZIONI PRIVACY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildPrivacyRow(
                          isDark: isDark,
                          icon: CupertinoIcons.location,
                          title: 'Condividi posizione',
                          subtitle: 'Permetti all\'app di utilizzare la tua posizione',
                          value: true,
                          onChanged: (value) {
                            // TODO: Salva preferenza
                          },
                          isFirst: true,
                        ),
                        _buildDivider(isDark),
                        _buildPrivacyRow(
                          isDark: isDark,
                          icon: CupertinoIcons.chart_bar,
                          title: 'Analisi utilizzo',
                          subtitle: 'Aiutaci a migliorare l\'app condividendo dati anonimi',
                          value: true,
                          onChanged: (value) {
                            // TODO: Salva preferenza
                          },
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Informazioni
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I tuoi dati',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(isDark),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'I tuoi dati personali sono protetti e utilizzati solo per fornirti i servizi dell\'app NULL. Non condividiamo i tuoi dati con terze parti senza il tuo consenso esplicito.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary(isDark),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Per maggiori informazioni, consulta l\'Informativa sulla privacy.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary(isDark),
                            height: 1.5,
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
      },
    );
  }

  Widget _buildPrivacyRow({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.iconBackground(isDark),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySecondary(isDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 68),
      height: 0.5,
      color: AppColors.borderColor(isDark),
    );
  }
}

