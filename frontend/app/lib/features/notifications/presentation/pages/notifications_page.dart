import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class NotificationsPage extends StatelessWidget {
  final ThemeManager themeManager;

  const NotificationsPage({
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
          'Notifiche',
          style: AppTextStyles.title(isDark),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 100), // Spazio per il footer
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.bell_slash,
                  size: 64,
                  color: AppColors.textSecondary(isDark),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nessuna notifica',
                  style: AppTextStyles.title(isDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le tue notifiche appariranno qui',
                  style: AppTextStyles.bodySecondary(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
