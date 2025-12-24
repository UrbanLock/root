import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/features/home/presentation/pages/home_page.dart';

/// Schermata obbligatoria per accettare:
/// - Termini e condizioni di utilizzo
/// - Informativa sulla privacy
///
/// Struttura a pagine orizzontali (come l'onboarding):
/// Pagina 0: Termini e condizioni
/// Pagina 1: Informativa privacy
///
/// L'utente deve scorrere il testo di ogni pagina fino in fondo
/// e accettare entrambe le sezioni; solo dopo viene chiamato [onAccepted].
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
  final PageController _pageController = PageController();
  final ScrollController _termsScrollController = ScrollController();
  final ScrollController _privacyScrollController = ScrollController();

  int _currentPage = 0;

  bool _termsScrolledToEnd = false;
  bool _privacyScrolledToEnd = false;

  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  @override
  void initState() {
    super.initState();
    _termsScrollController.addListener(_handleTermsScroll);
    _privacyScrollController.addListener(_handlePrivacyScroll);
  }

  @override
  void dispose() {
    _termsScrollController.removeListener(_handleTermsScroll);
    _privacyScrollController.removeListener(_handlePrivacyScroll);
    _termsScrollController.dispose();
    _privacyScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleTermsScroll() {
    if (!_termsScrolledToEnd &&
        _termsScrollController.position.pixels >=
            _termsScrollController.position.maxScrollExtent - 16) {
      setState(() {
        _termsScrolledToEnd = true;
      });
    }
  }

  void _handlePrivacyScroll() {
    if (!_privacyScrolledToEnd &&
        _privacyScrollController.position.pixels >=
            _privacyScrollController.position.maxScrollExtent - 16) {
      setState(() {
        _privacyScrolledToEnd = true;
      });
    }
  }

  void _onAcceptTerms() {
    if (!_termsScrolledToEnd || _termsAccepted) return;
    setState(() {
      _termsAccepted = true;
    });
    // Dopo aver accettato i termini, passa automaticamente alla pagina Privacy
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _onAcceptPrivacy() {
    if (!_privacyScrolledToEnd || _privacyAccepted) return;
    setState(() {
      _privacyAccepted = true;
    });
    // Una volta accettata la privacy (dopo aver letto fino in fondo),
    // chiudi la schermata tramite il callback dell'app (aggiorna stato / backend)
    widget.onAccepted();

    // E reindirizza sempre l'utente alla Home dell'app,
    // azzerando lo stack di navigazione per evitare schermate precedenti.
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(
        builder: (_) => HomePage(themeManager: widget.themeManager),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeManager,
      builder: (context, _) {
        final isDark = widget.themeManager.isDarkMode;

        final title = _currentPage == 0
            ? 'Termini di utilizzo'
            : 'Informativa sulla privacy';

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.surface(isDark),
            automaticallyImplyLeading:
                false, // Nessuna freccia indietro: accettazione obbligatoria
            middle: Text(
              title,
              style: AppTextStyles.title(isDark),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Contenuto paginato (Termini -> Privacy)
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      _buildTermsPage(isDark),
                      _buildPrivacyPage(isDark),
                    ],
                  ),
                ),
                // Indicatori di avanzamento (pagine)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface(isDark),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.borderColor(isDark).withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(2, (index) {
                        final isActive = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: isActive ? 24 : 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary(isDark)
                                : AppColors.textSecondary(isDark)
                                    .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
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

  Widget _buildTermsPage(bool isDark) {
    final canAccept = _termsScrolledToEnd && !_termsAccepted;
    final buttonColor = _termsAccepted
        ? CupertinoColors.systemGreen
        : (canAccept ? AppColors.primary(isDark) : AppColors.surface(isDark));
    final buttonText =
        _termsAccepted ? 'Termini accettati' : 'Ho letto e accetto i termini di utilizzo';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.shield_fill,
                  color: AppColors.primary(isDark),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Passaggio 1 di 2',
            style: AppTextStyles.bodySecondary(isDark),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CupertinoScrollbar(
              controller: _termsScrollController,
              child: SingleChildScrollView(
                controller: _termsScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _paragraph(
                      isDark,
                      '1. Accettazione dei termini',
                      'Utilizzando l\'app NULL, accetti di rispettare questi termini e condizioni. '
                          'Se non accetti questi termini, ti preghiamo di non utilizzare l\'app.',
                    ),
                    _paragraph(
                      isDark,
                      '2. Utilizzo del servizio',
                      'L\'app NULL è un servizio fornito dal Comune di Trento per la gestione dei lockers pubblici. '
                          'Il servizio è gratuito per tutti i cittadini di Trento. L\'utilizzo dei lockers è soggetto '
                          'alla disponibilità delle celle.',
                    ),
                    _paragraph(
                      isDark,
                      '3. Responsabilità dell\'utente',
                      'L\'utente è responsabile di:\n\n'
                          '• Utilizzare i lockers in modo corretto e rispettoso\n'
                          '• Non depositare oggetti pericolosi, illegali o di valore elevato\n'
                          '• Rispettare i tempi di utilizzo delle celle\n'
                          '• Mantenere la sicurezza delle proprie credenziali di accesso\n'
                          '• Segnalare eventuali problemi o malfunzionamenti',
                    ),
                    _paragraph(
                      isDark,
                      '4. Limitazione di responsabilità',
                      'Il Comune di Trento non si assume responsabilità per:\n\n'
                          '• Danni o perdite di oggetti depositati nei lockers\n'
                          '• Malfunzionamenti tecnici o interruzioni del servizio\n'
                          '• Utilizzo improprio dei lockers da parte degli utenti',
                    ),
                    _paragraph(
                      isDark,
                      '5. Modifiche ai termini',
                      'Il Comune di Trento si riserva il diritto di modificare questi termini in qualsiasi momento. '
                          'Le modifiche saranno comunicate agli utenti tramite l\'app o altri canali ufficiali.',
                    ),
                    _paragraph(
                      isDark,
                      '6. Contatti',
                      'Per domande o chiarimenti sui termini e condizioni, puoi contattare il supporto '
                          'all\'indirizzo supporto@null.trento.it o al numero +39 0461 123456.',
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        _termsScrolledToEnd
                            ? 'Hai raggiunto la fine dei termini.'
                            : 'Scorri fino in fondo per abilitare il pulsante di accettazione.',
                        style: AppTextStyles.bodySecondary(isDark),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          if (_termsScrolledToEnd) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(12),
                color: buttonColor,
                onPressed: canAccept ? _onAcceptTerms : null,
                child: Text(
                  buttonText,
                  style: TextStyle(
                    color: (canAccept || _termsAccepted)
                        ? CupertinoColors.white
                        : AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyPage(bool isDark) {
    final canAccept =
        _privacyScrolledToEnd && !_privacyAccepted && _termsAccepted;
    final buttonColor = _privacyAccepted
        ? CupertinoColors.systemGreen
        : (canAccept ? AppColors.primary(isDark) : AppColors.surface(isDark));
    final buttonText = _privacyAccepted
        ? 'Privacy accettata'
        : 'Ho letto e accetto l\'informativa sulla privacy';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.doc_text_fill,
                  color: AppColors.primary(isDark),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Passaggio 2 di 2',
            style: AppTextStyles.bodySecondary(isDark),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CupertinoScrollbar(
              controller: _privacyScrollController,
              child: SingleChildScrollView(
                controller: _privacyScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _paragraph(
                      isDark,
                      '1. Titolare del trattamento',
                      'Il titolare del trattamento dei dati personali è il Comune di Trento, con sede in Via Manci, 2 - 38122 Trento. '
                          'Per contatti: privacy@comune.trento.it.',
                    ),
                    _paragraph(
                      isDark,
                      '2. Dati raccolti',
                      'L\'app NULL raccoglie i seguenti dati personali:\n\n'
                          '• Dati di registrazione (nome, email, telefono)\n'
                          '• Dati di utilizzo (storico prenotazioni, celle utilizzate)\n'
                          '• Dati di localizzazione (posizione GPS per trovare i lockers più vicini)\n'
                          '• Dati tecnici (indirizzo IP, tipo di dispositivo, sistema operativo)',
                    ),
                    _paragraph(
                      isDark,
                      '3. Finalità del trattamento',
                      'I dati personali vengono utilizzati per:\n\n'
                          '• Fornire i servizi dell\'app (prenotazione celle, gestione account)\n'
                          '• Migliorare l\'esperienza utente e il funzionamento dell\'app\n'
                          '• Comunicare con l\'utente per questioni relative al servizio\n'
                          '• Rispettare obblighi di legge e regolamentari',
                    ),
                    _paragraph(
                      isDark,
                      '4. Base giuridica',
                      'Il trattamento dei dati personali si basa su:\n\n'
                          '• Consenso dell\'interessato\n'
                          '• Esecuzione di un contratto (fornitura del servizio)\n'
                          '• Interesse legittimo del titolare (miglioramento del servizio)\n'
                          '• Obblighi di legge',
                    ),
                    _paragraph(
                      isDark,
                      '5. Conservazione dei dati',
                      'I dati personali vengono conservati per il tempo necessario alle finalità per cui sono stati raccolti, '
                          'e comunque non oltre i termini previsti dalla legge. I dati di utilizzo vengono conservati per un massimo '
                          'di 2 anni dalla data di ultimo utilizzo.',
                    ),
                    _paragraph(
                      isDark,
                      '6. Diritti dell\'interessato',
                      'Ai sensi del GDPR, l\'utente ha diritto a:\n\n'
                          '• Accedere ai propri dati personali\n'
                          '• Richiedere la rettifica o la cancellazione dei dati\n'
                          '• Opporsi al trattamento dei dati\n'
                          '• Richiedere la limitazione del trattamento\n'
                          '• Richiedere la portabilità dei dati\n'
                          '• Revocare il consenso in qualsiasi momento',
                    ),
                    _paragraph(
                      isDark,
                      '7. Comunicazione dei dati',
                      'I dati personali non vengono comunicati a terze parti, salvo:\n\n'
                          '• Fornitori di servizi tecnici (hosting, cloud) che operano come responsabili del trattamento\n'
                          '• Autorità competenti in caso di obblighi di legge\n'
                          '• Con il consenso esplicito dell\'utente',
                    ),
                    _paragraph(
                      isDark,
                      '8. Sicurezza dei dati',
                      'Il Comune di Trento adotta misure tecniche e organizzative appropriate per proteggere i dati personali '
                          'da accesso non autorizzato, perdita, distruzione o alterazione.',
                    ),
                    _paragraph(
                      isDark,
                      '9. Contatti',
                      'Per esercitare i propri diritti o per richiedere informazioni sul trattamento dei dati, '
                          'l\'utente può contattare:\n\n'
                          'Email: privacy@comune.trento.it\n'
                          'Telefono: +39 0461 123456\n'
                          'Indirizzo: Comune di Trento, Via Manci, 2 - 38122 Trento',
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        _privacyScrolledToEnd
                            ? 'Hai raggiunto la fine dell\'informativa.'
                            : 'Scorri fino in fondo per abilitare il pulsante di accettazione.',
                        style: AppTextStyles.bodySecondary(isDark),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          if (_privacyScrolledToEnd) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(12),
                color: buttonColor,
                onPressed: canAccept ? _onAcceptPrivacy : null,
                child: Text(
                  buttonText,
                  style: TextStyle(
                    color: (canAccept || _privacyAccepted)
                        ? CupertinoColors.white
                        : AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paragraph(
    bool isDark,
    String title,
    String content,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

