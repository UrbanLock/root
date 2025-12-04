import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class ProfilePopup extends StatelessWidget {
  final bool isAuthenticated;
  final VoidCallback? onLoginTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onActiveReservationsTap;
  final VoidCallback? onReportsTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onDonateTap;
  final String? userName;
  final String? userEmail;
  final ThemeManager themeManager;

  const ProfilePopup({
    super.key,
    required this.isAuthenticated,
    required this.themeManager,
    this.onLoginTap,
    this.onLogoutTap,
    this.onHistoryTap,
    this.onActiveReservationsTap,
    this.onReportsTap,
    this.onHelpTap,
    this.onDonateTap,
    this.userName,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, _) {
        final isDark = themeManager.isDarkMode;

        return GestureDetector(
          onTap: () {
            // Previene la chiusura quando si clicca dentro il popup
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 260,
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.borderColor(isDark).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: isAuthenticated
                    ? _buildAuthenticatedView(context, isDark)
                    : _buildUnauthenticatedView(context, isDark),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthenticatedView(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header profilo
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.person_fill,
                  size: 24,
                  color: AppColors.primary(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  userName ?? 'Utente',
                  style: AppTextStyles.title(isDark),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),
        // Lista opzioni
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuItem(
                  context: context,
                  isDark: isDark,
                  icon: CupertinoIcons.clock,
                  title: 'Storico utilizzi',
                  onTap: onHistoryTap,
                ),
                _buildMenuItem(
                  context: context,
                  isDark: isDark,
                  icon: CupertinoIcons.lock,
                  title: 'Celle attive',
                  onTap: onActiveReservationsTap,
                ),
                _buildMenuItem(
                  context: context,
                  isDark: isDark,
                  icon: CupertinoIcons.gift,
                  title: 'Donare un oggetto',
                  onTap: onDonateTap,
                ),
                _buildMenuItem(
                  context: context,
                  isDark: isDark,
                  icon: CupertinoIcons.exclamationmark_triangle,
                  title: 'Segnalazioni',
                  onTap: onReportsTap,
                ),
                _buildMenuItem(
                  context: context,
                  isDark: isDark,
                  icon: CupertinoIcons.question_circle,
                  title: 'Aiuto e supporto',
                  onTap: onHelpTap,
                ),
                const SizedBox(height: 8),
                Divider(height: 1),
                const SizedBox(height: 8),
                // Logout
                _buildMenuItem(
                  context: context,
                  isDark: isDark,
                  icon: CupertinoIcons.arrow_right_square,
                  title: 'Esci',
                  titleColor: CupertinoColors.systemRed,
                  onTap: onLogoutTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context, bool isDark) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.person_crop_circle,
              size: 40,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              'Accedi per vedere il tuo profilo',
              style: AppTextStyles.body(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              borderRadius: BorderRadius.circular(12),
              onPressed: onLoginTap,
              child: const Text(
                'Accedi',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    Color? titleColor,
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
                color: titleColor ?? AppColors.primary(isDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor ?? AppColors.text(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textSecondary(isDark),
            ),
          ],
        ),
      ),
    );
  }
}

