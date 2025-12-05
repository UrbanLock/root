import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/localization/localization_manager.dart';
import 'package:app/features/profile/presentation/pages/help_page.dart';
import 'package:app/features/settings/presentation/pages/privacy_page.dart';
import 'package:app/features/settings/presentation/pages/terms_page.dart';
import 'package:app/features/settings/presentation/pages/privacy_policy_page.dart';
import 'package:app/features/settings/presentation/pages/language_page.dart';

class SettingsPage extends StatefulWidget {
  final ThemeManager themeManager;
  final bool isAuthenticated;
  final ValueChanged<bool>? onAuthenticationChanged;

  const SettingsPage({
    super.key,
    required this.themeManager,
    this.isAuthenticated = false,
    this.onAuthenticationChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LocalizationManager _localizationManager = LocalizationManager();
  
  // Impostazioni notifiche (mock - in produzione verranno salvate in SharedPreferences)
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.themeManager, _localizationManager]),
      builder: (context, _) {
        final isDark = widget.themeManager.isDarkMode;
        final t = _localizationManager.translate;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: Text(
              t('settings'),
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sezione Aspetto (prima di tutto)
                Text(
                  t('appearance').toUpperCase(),
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
                      _buildSettingsRow(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.moon_fill,
                        title: t('dark_mode'),
                        subtitle: isDark ? t('dark_mode_active') : t('dark_mode_inactive'),
                        trailing: CupertinoSwitch(
                          value: isDark,
                          onChanged: (value) {
                            widget.themeManager.setTheme(value);
                          },
                          activeColor: AppColors.primary(isDark),
                        ),
                        isFirst: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sezione Notifiche
                Text(
                  t('notifications').toUpperCase(),
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
                      _buildSettingsRow(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.bell,
                        title: t('push_notifications'),
                        subtitle: t('push_notifications_subtitle'),
                        trailing: CupertinoSwitch(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                              if (!value) {
                                _pushNotificationsEnabled = false;
                              }
                            });
                          },
                          activeColor: AppColors.primary(isDark),
                        ),
                        isFirst: true,
                      ),
                      if (_notificationsEnabled) ...[
                        _buildDivider(isDark),
                        _buildSettingsRow(
                          context: context,
                          isDark: isDark,
                          icon: CupertinoIcons.bell_fill,
                          title: 'Notifiche push',
                          subtitle: 'Notifiche immediate',
                          trailing: CupertinoSwitch(
                            value: _pushNotificationsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _pushNotificationsEnabled = value;
                              });
                            },
                            activeColor: AppColors.primary(isDark),
                          ),
                        ),
                      ] else
                        _buildSettingsRow(
                          context: context,
                          isDark: isDark,
                          icon: CupertinoIcons.bell_fill,
                          title: 'Notifiche push',
                          subtitle: 'Notifiche immediate',
                          trailing: CupertinoSwitch(
                            value: false,
                            onChanged: null,
                            activeColor: AppColors.primary(isDark),
                          ),
                          isLast: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sezione Privacy e Sicurezza
                Text(
                  t('privacy_security').toUpperCase(),
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
                      _buildSettingsRow(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.lock,
                        title: t('privacy'),
                        subtitle: t('privacy_subtitle'),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => PrivacyPage(
                                themeManager: widget.themeManager,
                              ),
                            ),
                          );
                        },
                        isFirst: true,
                      ),
                      _buildDivider(isDark),
                      _buildSettingsRow(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.shield,
                        title: t('terms_conditions'),
                        subtitle: t('terms_conditions_subtitle'),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => TermsPage(
                                themeManager: widget.themeManager,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildDivider(isDark),
                      _buildSettingsRow(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.doc_text,
                        title: t('privacy_policy'),
                        subtitle: t('privacy_policy_subtitle'),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => PrivacyPolicyPage(
                                themeManager: widget.themeManager,
                              ),
                            ),
                          );
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sezione Supporto
                Text(
                  t('support').toUpperCase(),
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
                      _buildSettingsRow(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.question_circle_fill,
                        title: t('help_support'),
                        subtitle: t('help_support_subtitle'),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => HelpPage(
                                themeManager: widget.themeManager,
                              ),
                            ),
                          );
                        },
                        isFirst: true,
                      ),
                      _buildDivider(isDark),
                      _buildSettingsRow(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.info_circle_fill,
                        title: t('info'),
                        subtitle: t('info_subtitle'),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                        ),
                        onTap: () {
                          _showInfoDialog(context, isDark);
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sezione Generale
                Text(
                  t('general').toUpperCase(),
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
                      _buildSettingsRow(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.globe,
                        title: t('language'),
                        subtitle: _localizationManager.getLanguageName(_localizationManager.currentLocale.languageCode),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => LanguagePage(
                                themeManager: widget.themeManager,
                              ),
                            ),
                          );
                        },
                        isFirst: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsRow({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
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
                color: titleColor ?? AppColors.primary(isDark),
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
                      color: titleColor ?? AppColors.text(isDark),
                    ),
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
              trailing,
            ],
          ],
        ),
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

  void _showInfoDialog(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Informazioni'),
        content: const Text(
          'NULL - App per la gestione dei lockers\n\n'
          'Versione: 1.0.0\n'
          'Sviluppato per il Comune di Trento\n\n'
          '© 2024 NULL. Tutti i diritti riservati.',
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
  }
}
