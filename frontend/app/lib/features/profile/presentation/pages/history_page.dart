import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class HistoryPage extends StatelessWidget {
  final ThemeManager themeManager;

  const HistoryPage({
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
          'Storico utilizzi',
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
                  Text(
                    'I tuoi utilizzi',
                    style: AppTextStyles.title(isDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visualizza la cronologia dei lockers che hai utilizzato',
                    style: AppTextStyles.bodySecondary(isDark),
                  ),
                ],
              ),
            ),
            // Lista storico (per ora vuota - mock data)
            Container(
              color: AppColors.surface(isDark),
              child: Column(
                children: [
                  _buildHistoryItem(
                    context: context,
                    isDark: isDark,
                    lockerName: 'Parco delle Albere',
                    lockerType: 'Sportivi',
                    date: '15 Gen 2024',
                    time: '14:30 - 16:45',
                    status: 'Completato',
                  ),
                  Divider(height: 1, color: AppColors.borderColor(isDark)),
                  _buildHistoryItem(
                    context: context,
                    isDark: isDark,
                    lockerName: 'Centro Storico - Piazza Duomo',
                    lockerType: 'Personali',
                    date: '12 Gen 2024',
                    time: '10:15 - 12:30',
                    status: 'Completato',
                  ),
                  Divider(height: 1, color: AppColors.borderColor(isDark)),
                  _buildHistoryItem(
                    context: context,
                    isDark: isDark,
                    lockerName: 'Stazione FS',
                    lockerType: 'Personali',
                    date: '8 Gen 2024',
                    time: '09:00 - 11:20',
                    status: 'Completato',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Messaggio se vuoto (per ora nascosto)
            if (false)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 64,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nessun utilizzo',
                      style: AppTextStyles.title(isDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'I tuoi utilizzi dei lockers appariranno qui',
                      style: AppTextStyles.bodySecondary(isDark),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required BuildContext context,
    required bool isDark,
    required String lockerName,
    required String lockerType,
    required String date,
    required String time,
    required String status,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        // TODO: Mostra dettagli utilizzo
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.iconBackground(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.lock,
                size: 24,
                color: AppColors.primary(isDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lockerName,
                    style: AppTextStyles.body(isDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lockerType,
                    style: AppTextStyles.bodySecondary(isDark),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$date • $time',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

