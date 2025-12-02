import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class ActiveReservationsPage extends StatefulWidget {
  final ThemeManager themeManager;

  const ActiveReservationsPage({
    super.key,
    required this.themeManager,
  });

  @override
  State<ActiveReservationsPage> createState() => _ActiveReservationsPageState();
}

class _ActiveReservationsPageState extends State<ActiveReservationsPage> {
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
              'Celle attive',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.lock,
                      size: 64,
                      color: AppColors.textSecondary(isDark).withOpacity(0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Nessuna cella attiva',
                      style: AppTextStyles.title(isDark).copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le tue celle attive appariranno qui',
                      style: AppTextStyles.bodySecondary(isDark),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
