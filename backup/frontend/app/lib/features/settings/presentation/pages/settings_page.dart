import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class SettingsPage extends StatelessWidget {
  final ThemeManager themeManager;

  const SettingsPage({
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
          'Impostazioni',
          style: AppTextStyles.title(isDark),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100), // Spazio per il footer
          children: [
            // Sezione Aspetto
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'ASPETTO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(isDark),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              color: AppColors.surface(isDark),
              child: Column(
                children: [
                  _buildSettingsRow(
                    context: context,
                    icon: CupertinoIcons.moon_fill,
                    title: 'Modalità scura',
                    subtitle: isDark ? 'Attiva' : 'Disattiva',
                    isDark: isDark,
                    trailing: CupertinoSwitch(
                      value: isDark,
                      onChanged: (value) {
                        themeManager.setTheme(value);
                      },
                      activeColor: AppColors.primary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Sezione Supporto
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'SUPPORTO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(isDark),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              color: AppColors.surface(isDark),
              child: Column(
                children: [
                  _buildSettingsRow(
                    context: context,
                    icon: CupertinoIcons.question_circle_fill,
                    title: 'Help',
                    subtitle: 'Domande frequenti e supporto',
                    isDark: isDark,
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 18,
                    ),
                    onTap: () {
                      _showHelpDialog(context, isDark);
                    },
                  ),
                  _buildDivider(isDark),
                  _buildSettingsRow(
                    context: context,
                    icon: CupertinoIcons.info_circle_fill,
                    title: 'Informazioni',
                    subtitle: 'Versione 1.0.0',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.iconBackground(isDark),
                borderRadius: BorderRadius.circular(8),
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
                    style: AppTextStyles.body(isDark),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySecondary(isDark),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              DefaultTextStyle(
                style: TextStyle(color: AppColors.textSecondary(isDark)),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 60),
      height: 0.5,
      color: AppColors.borderSecondary(isDark),
    );
  }

  void _showHelpDialog(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Help'),
        content: const Text(
          'Benvenuto in NULL!\n\n'
          'NULL è un\'app per trovare e gestire parcheggi nella tua città.\n\n'
          '• Usa la mappa per esplorare i parcheggi disponibili\n'
          '• Cerca parcheggi usando la barra di ricerca\n'
          '• Attiva le notifiche per ricevere aggiornamenti\n\n'
          'Per assistenza, contatta il supporto.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
