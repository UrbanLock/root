import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class HelpPage extends StatelessWidget {
  final ThemeManager themeManager;

  const HelpPage({
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
          'Aiuto e supporto',
          style: AppTextStyles.title(isDark),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.question_circle_fill,
                    size: 48,
                    color: AppColors.primary(isDark),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Come possiamo aiutarti?',
                    style: AppTextStyles.title(isDark),
                  ),
                ],
              ),
            ),
            // FAQ
            Container(
              color: AppColors.surface(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      'DOMANDE FREQUENTI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildFAQItem(
                    context: context,
                    isDark: isDark,
                    question: 'Come funzionano i lockers?',
                    answer:
                        'I lockers sono armadietti intelligenti distribuiti per la città. Puoi prenotare una cella tramite l\'app, depositare i tuoi oggetti e ritirarli quando preferisci.',
                  ),
                  Divider(height: 1, color: AppColors.borderColor(isDark)),
                  _buildFAQItem(
                    context: context,
                    isDark: isDark,
                    question: 'Quanto costa utilizzare un locker?',
                    answer:
                        'L\'utilizzo dei lockers è gratuito per tutti i cittadini di Trento. Il servizio è finanziato dal Comune per promuovere la mobilità sostenibile.',
                  ),
                  Divider(height: 1, color: AppColors.borderColor(isDark)),
                  _buildFAQItem(
                    context: context,
                    isDark: isDark,
                    question: 'Come posso sbloccare una cella?',
                    answer:
                        'Dopo aver prenotato una cella, puoi sbloccarla direttamente dall\'app utilizzando il pulsante "Apri" nella sezione delle prenotazioni attive.',
                  ),
                  Divider(height: 1, color: AppColors.borderColor(isDark)),
                  _buildFAQItem(
                    context: context,
                    isDark: isDark,
                    question: 'Cosa posso depositare nei lockers?',
                    answer:
                        'Puoi depositare oggetti personali, attrezzature sportive, borse, libri e altri oggetti di uso quotidiano. Non sono ammessi oggetti pericolosi o di valore elevato.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Contatti
            Container(
              color: AppColors.surface(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      'CONTATTI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildContactItem(
                    context: context,
                    isDark: isDark,
                    icon: CupertinoIcons.mail,
                    title: 'Email supporto',
                    subtitle: 'supporto@null.trento.it',
                    onTap: () {
                      // TODO: Apri email
                    },
                  ),
                  Divider(height: 1, color: AppColors.borderColor(isDark)),
                  _buildContactItem(
                    context: context,
                    isDark: isDark,
                    icon: CupertinoIcons.phone,
                    title: 'Telefono',
                    subtitle: '+39 0461 123456',
                    onTap: () {
                      // TODO: Chiama
                    },
                  ),
                  Divider(height: 1, color: AppColors.borderColor(isDark)),
                  _buildContactItem(
                    context: context,
                    isDark: isDark,
                    icon: CupertinoIcons.exclamationmark_triangle,
                    title: 'Segnala un problema',
                    subtitle: 'Segnala guasti o malfunzionamenti',
                    onTap: () {
                      // TODO: Apri form segnalazione
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required BuildContext context,
    required bool isDark,
    required String question,
    required String answer,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(
              question,
              style: TextStyle(color: AppColors.text(isDark)),
            ),
            content: Text(
              answer,
              style: TextStyle(color: AppColors.textSecondary(isDark)),
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
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                question,
                style: AppTextStyles.body(isDark),
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

  Widget _buildContactItem({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    style: AppTextStyles.body(isDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySecondary(isDark),
                  ),
                ],
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

