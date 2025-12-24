import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class PrivacyTermsPage extends StatefulWidget {
  final ThemeManager themeManager;
  final VoidCallback onAccepted;

  const PrivacyTermsPage({
    super.key,
    required this.themeManager,
    required this.onAccepted,
  });

  @override
  State<PrivacyTermsPage> createState() => _PrivacyTermsPageState();
}

class _PrivacyTermsPageState extends State<PrivacyTermsPage> {
  bool _privacyAccepted = false;
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeManager,
      builder: (context, _) {
        final isDark = widget.themeManager.isDarkMode;
        final allAccepted = _privacyAccepted && _termsAccepted;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            middle: Text(
              'Privacy e Termini',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prima di continuare, accetta la nostra Informativa sulla Privacy e i Termini e Condizioni del servizio.',
                    style: AppTextStyles.bodySecondary(isDark),
                  ),
                  const SizedBox(height: 24),
                  _buildCheckboxTile(
                    isDark: isDark,
                    title: 'Accetto l\'Informativa sulla Privacy',
                    value: _privacyAccepted,
                    onChanged: (value) {
                      setState(() {
                        _privacyAccepted = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCheckboxTile(
                    isDark: isDark,
                    title: 'Accetto i Termini e Condizioni',
                    value: _termsAccepted,
                    onChanged: (value) {
                      setState(() {
                        _termsAccepted = value ?? false;
                      });
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: allAccepted ? widget.onAccepted : null,
                      child: const Text(
                        'Continua',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _buildCheckboxTile({
    required bool isDark,
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderColor(isDark).withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            CupertinoCheckbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary(isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/theme/theme_manager.dart';

class PrivacyTermsPage extends StatelessWidget {
  final ThemeManager themeManager;

  const PrivacyTermsPage({
    super.key,
    required this.themeManager,
  });

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_terms_accepted_v1', true);
    Navigator.of(context).pop(true);
  }

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
              'Privacy e Termini',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informativa sulla privacy',
                          style: AppTextStyles.title(isDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'I tuoi dati saranno utilizzati esclusivamente per fornire i servizi dell\'app NULL, '
                          'in conformità con il GDPR e le normative vigenti. Puoi richiedere in qualsiasi momento '
                          'la cancellazione del tuo account e dei tuoi dati.',
                          style: AppTextStyles.body(isDark),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Termini di utilizzo',
                          style: AppTextStyles.title(isDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Utilizzando l\'app ti impegni a:\n'
                          '- utilizzare i lockers in modo corretto e rispettoso;\n'
                          '- non depositare oggetti vietati o pericolosi;\n'
                          '- rispettare i tempi di utilizzo indicati per ogni servizio.\n\n'
                          'Eventuali abusi potranno comportare la sospensione o chiusura dell\'account.',
                          style: AppTextStyles.body(isDark),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: AppColors.surface(isDark),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Annulla',
                            style: AppTextStyles.body(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton.filled(
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onPressed: () => _accept(context),
                          child: const Text(
                            'Accetta',
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
              ],
            ),
          ),
        );
      },
    );
  }
}


