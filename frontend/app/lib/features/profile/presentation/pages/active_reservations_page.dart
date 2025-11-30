import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class ActiveReservationsPage extends StatelessWidget {
  final ThemeManager themeManager;

  const ActiveReservationsPage({
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
          'Prenotazioni attive',
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
                    'Le tue prenotazioni',
                    style: AppTextStyles.title(isDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gestisci i lockers che stai attualmente utilizzando',
                    style: AppTextStyles.bodySecondary(isDark),
                  ),
                ],
              ),
            ),
            // Lista prenotazioni attive (per ora vuota - mock data)
            Container(
              color: AppColors.surface(isDark),
              child: Column(
                children: [
                  _buildReservationItem(
                    context: context,
                    isDark: isDark,
                    lockerName: 'Parco delle Albere',
                    lockerType: 'Sportivi',
                    cellNumber: 'Cella 3',
                    startTime: 'Oggi, 14:30',
                    endTime: 'Scade tra 2h 15min',
                    isActive: true,
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
                      CupertinoIcons.lock,
                      size: 64,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nessuna prenotazione attiva',
                      style: AppTextStyles.title(isDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le tue prenotazioni attive appariranno qui',
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

  Widget _buildReservationItem({
    required BuildContext context,
    required bool isDark,
    required String lockerName,
    required String lockerType,
    required String cellNumber,
    required String startTime,
    required String endTime,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.iconBackground(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.lock_fill,
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
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Attiva',
                  style: TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.systemGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cella',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cellNumber,
                      style: AppTextStyles.body(isDark),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inizio',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      startTime,
                      style: AppTextStyles.body(isDark),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scadenza',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endTime,
                      style: AppTextStyles.body(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: AppColors.primary(isDark),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    // TODO: Apri cella
                  },
                  child: const Text(
                    'Apri',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    // TODO: Chiudi prenotazione
                  },
                  child: Text(
                    'Chiudi',
                    style: TextStyle(
                      color: AppColors.text(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

