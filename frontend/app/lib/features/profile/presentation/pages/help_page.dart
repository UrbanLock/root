import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/reports/presentation/pages/report_issue_page.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpPage extends StatelessWidget {
  final ThemeManager themeManager;

  const HelpPage({
    super.key,
    required this.themeManager,
  });

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
              'Aiuto e supporto',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            bottom: false,
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
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary(isDark).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          CupertinoIcons.question_circle_fill,
                          size: 32,
                          color: AppColors.primary(isDark),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Come possiamo aiutarti?',
                        style: AppTextStyles.title(isDark),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Trova risposte alle domande più frequenti o contatta il nostro supporto.',
                        style: AppTextStyles.bodySecondary(isDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Domande frequenti
                Text(
                  'DOMANDE FREQUENTI',
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
                      _buildFAQItem(
                        context: context,
                        isDark: isDark,
                        question: 'Come funzionano i lockers?',
                        answer:
                            'I lockers sono armadietti intelligenti distribuiti per la città. Puoi prenotare una cella tramite l\'app, depositare i tuoi oggetti e ritirarli quando preferisci. Ogni locker è dotato di tecnologia Bluetooth per l\'apertura automatica delle celle.',
                        isFirst: true,
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 16),
                        color: AppColors.borderColor(isDark),
                      ),
                      _buildFAQItem(
                        context: context,
                        isDark: isDark,
                        question: 'Quanto costa utilizzare un locker?',
                        answer:
                            'L\'utilizzo dei lockers è gratuito per tutti i cittadini di Trento. Il servizio è finanziato dal Comune per promuovere la mobilità sostenibile e la condivisione di risorse nella comunità.',
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 16),
                        color: AppColors.borderColor(isDark),
                      ),
                      _buildFAQItem(
                        context: context,
                        isDark: isDark,
                        question: 'Come posso sbloccare una cella?',
                        answer:
                            'Dopo aver prenotato una cella, puoi sbloccarla direttamente dall\'app utilizzando il pulsante "Apri" nella sezione delle prenotazioni attive. Avvicinati al locker e l\'app si connetterà automaticamente via Bluetooth per aprire la cella assegnata.',
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 16),
                        color: AppColors.borderColor(isDark),
                      ),
                      _buildFAQItem(
                        context: context,
                        isDark: isDark,
                        question: 'Cosa posso depositare nei lockers?',
                        answer:
                            'Puoi depositare oggetti personali, attrezzature sportive, borse, libri e altri oggetti di uso quotidiano. Non sono ammessi oggetti pericolosi, deperibili, di valore elevato o illegali. Per maggiori informazioni consulta i termini di utilizzo.',
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 16),
                        color: AppColors.borderColor(isDark),
                      ),
                      _buildFAQItem(
                        context: context,
                        isDark: isDark,
                        question: 'Quanto tempo posso tenere una cella?',
                        answer:
                            'Il tempo di utilizzo dipende dal tipo di servizio: per i prestiti di oggetti il tempo è variabile, per i depositi temporanei puoi scegliere la durata al momento del pagamento (ore o giorni). Riceverai notifiche prima della scadenza.',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Contatti e supporto
                Text(
                  'CONTATTI E SUPPORTO',
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
                      _buildContactItem(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.mail,
                        title: 'Email supporto',
                        subtitle: 'supporto@null.trento.it',
                        onTap: () async {
                          final Uri emailUri = Uri(
                            scheme: 'mailto',
                            path: 'supporto@null.trento.it',
                          );
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(emailUri);
                          }
                        },
                        isFirst: true,
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 16),
                        color: AppColors.borderColor(isDark),
                      ),
                      _buildContactItem(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.phone,
                        title: 'Telefono',
                        subtitle: '+39 0461 123456',
                        onTap: () async {
                          final Uri phoneUri = Uri(
                            scheme: 'tel',
                            path: '+390461123456',
                          );
                          if (await canLaunchUrl(phoneUri)) {
                            await launchUrl(phoneUri);
                          }
                        },
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 16),
                        color: AppColors.borderColor(isDark),
                      ),
                      _buildContactItem(
                        context: context,
                        isDark: isDark,
                        icon: CupertinoIcons.exclamationmark_triangle,
                        title: 'Segnala un problema',
                        subtitle: 'Segnala guasti o malfunzionamenti',
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => ReportIssuePage(
                                themeManager: themeManager,
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
                
                // Informazioni aggiuntive
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface(isDark),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.info_circle,
                            size: 20,
                            color: AppColors.primary(isDark),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Informazioni',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Orari di assistenza:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lun-Ven: 9:00 - 18:00\nSab: 9:00 - 13:00\nDom: Chiuso',
                        style: AppTextStyles.bodySecondary(isDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Versione app: 1.0.0',
                        style: AppTextStyles.bodySecondary(isDark),
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

  Widget _buildFAQItem({
    required BuildContext context,
    required bool isDark,
    required String question,
    required String answer,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => FAQDetailPage(
              themeManager: themeManager,
              question: question,
              answer: answer,
            ),
          ),
        );
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
                    question,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    answer.length > 80 ? '${answer.substring(0, 80)}...' : answer,
                    style: AppTextStyles.bodySecondary(isDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

/// Pagina di dettaglio per una singola FAQ
class FAQDetailPage extends StatelessWidget {
  final ThemeManager themeManager;
  final String question;
  final String answer;

  const FAQDetailPage({
    super.key,
    required this.themeManager,
    required this.question,
    required this.answer,
  });

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
              'Domanda frequente',
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icona
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary(isDark).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      CupertinoIcons.question_circle_fill,
                      size: 32,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Domanda
                  Text(
                    question,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(isDark),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Risposta
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      answer,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: AppColors.text(isDark),
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
}
