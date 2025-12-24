import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/features/auth/presentation/pages/privacy_terms_page.dart';

class LoginPage extends StatefulWidget {
  final Function(bool) onLoginSuccess;
  final ThemeManager themeManager;

  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    required this.themeManager,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String? _errorMessage;

  /// Genera un codice fiscale di test casuale (16 caratteri)
  String _generateTestCodiceFiscale() {
    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    final raw = 'TSTUSR$millis'.toUpperCase();
    return raw.padRight(16, 'X').substring(0, 16);
  }

  Future<void> _handleLogin(String tipoAutenticazione) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepository = AppDependencies.authRepository;
      if (authRepository == null) {
        throw Exception('Servizio di autenticazione non disponibile');
      }

      // Genera un codice fiscale di test per il login (mock SPID/CIE)
      final codiceFiscale = _generateTestCodiceFiscale();

      final loginResponse = await authRepository.login(
        codiceFiscale: codiceFiscale,
        tipoAutenticazione: tipoAutenticazione,
      );

      // Salva i token
      final authService = AppDependencies.authService;
      if (authService != null) {
        await authService.saveTokens(
          accessToken: loginResponse.accessToken,
          refreshToken: loginResponse.refreshToken,
          expiresInSeconds: loginResponse.expiresIn,
        );
      }

      if (mounted) {
        widget.onLoginSuccess(true);

        // Controlla se l'utente ha già accettato privacy e termini
        final prefs = await SharedPreferences.getInstance();
        final privacyTermsAccepted =
            prefs.getBool('privacy_terms_accepted_v1') ?? false;

        if (!privacyTermsAccepted) {
          // Se non ha accettato, naviga alla pagina di privacy/termini.
          // La schermata di privacy, una volta accettata, porterà l'utente alla Home.
          await Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (context) => PrivacyTermsPage(
                themeManager: widget.themeManager,
                onAccepted: () async {
                  // Registra accettazione termini sul backend (best effort)
                  try {
                    await authRepository.acceptTerms(version: 'v1');
                  } catch (_) {
                    // Se fallisce, continuiamo comunque a livello locale
                  }
                  await prefs.setBool('privacy_terms_accepted_v1', true);
                },
              ),
            ),
          );
        } else {
          // Se già accettati, torna semplicemente alla Home
          Navigator.of(context).pop();
        }
      }
    } on ValidationException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore durante il login: $e';
        _isLoading = false;
      });
    }
  }

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
              'Accedi',
              style: TextStyle(
                color: AppColors.text(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: CupertinoNavigationBarBackButton(
              color: AppColors.primary(isDark),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Schermata di benvenuto (parte superiore)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.person_crop_circle_fill,
                            size: 80,
                            color: AppColors.primary(isDark),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Benvenuto in NULL',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(isDark),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Accedi per utilizzare tutti i servizi',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary(isDark),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Pulsanti di login (parte inferiore)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      // Pulsante Login con SPID
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _isLoading
                              ? null
                              : () => _handleLogin('spid'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.shield_fill,
                                color: CupertinoColors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Accedi con SPID',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Pulsante Login con CIE
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.primary(isDark),
                          onPressed: _isLoading
                              ? null
                              : () => _handleLogin('cie'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.creditcard_fill,
                                color: CupertinoColors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Accedi con CIE',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 16),
                        const CupertinoActivityIndicator(),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: CupertinoColors.systemRed,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

