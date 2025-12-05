import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/localization/localization_manager.dart';

/// Pagina per la selezione della lingua
class LanguagePage extends StatefulWidget {
  final ThemeManager themeManager;

  const LanguagePage({
    super.key,
    required this.themeManager,
  });

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  final LocalizationManager _localizationManager = LocalizationManager();
  
  // Lingua selezionata (mock - in produzione verrà salvata in SharedPreferences)
  String _selectedLanguage = 'it';

  final List<Map<String, String>> _languages = [
    {'code': 'it', 'name': 'Italiano', 'nativeName': 'Italiano'},
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'de', 'name': 'Deutsch', 'nativeName': 'Deutsch'},
    {'code': 'fr', 'name': 'Français', 'nativeName': 'Français'},
    {'code': 'es', 'name': 'Español', 'nativeName': 'Español'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _localizationManager.currentLocale.languageCode;
  }

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
              t('language'),
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
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
                        CupertinoIcons.globe,
                        size: 48,
                        color: AppColors.primary(isDark),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('select_language'),
                        style: AppTextStyles.title(isDark),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('select_language_subtitle'),
                        style: AppTextStyles.bodySecondary(isDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Lista lingue
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(isDark),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: _languages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final language = entry.value;
                      final isSelected = language['code'] == _selectedLanguage;
                      final isFirst = index == 0;
                      final isLast = index == _languages.length - 1;

                      return Column(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _selectedLanguage = language['code']!;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          language['nativeName']!,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.text(isDark),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          language['name']!,
                                          style: AppTextStyles.bodySecondary(isDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      size: 24,
                                      color: AppColors.primary(isDark),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              height: 0.5,
                              color: AppColors.borderColor(isDark),
                            ),
                        ],
                      );
                    }).toList(),
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
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle,
                        size: 20,
                        color: AppColors.primary(isDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t('language_change_info'),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(isDark),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Pulsante Applica
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final locale = Locale(_selectedLanguage);
                    _localizationManager.setLocale(locale);
                    Navigator.of(context).pop();
                    // Mostra messaggio di conferma
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text(t('language')),
                        content: Text(t('language_change_info')),
                        actions: [
                          CupertinoDialogAction(
                            isDefaultAction: true,
                            child: Text(t('ok')),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t('apply'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
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
}

