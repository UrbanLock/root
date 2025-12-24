import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/notifications/notification_service.dart';
import 'package:app/features/home/presentation/pages/home_page.dart';
import 'package:app/features/auth/presentation/pages/onboarding_page.dart';
import 'package:app/features/auth/presentation/pages/privacy_terms_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza le dipendenze (API client, auth service, ecc.)
  await AppDependencies.initialize();

  // Inizializza il servizio di notifiche
  await NotificationService().initialize();

  // Leggi il tema di sistema PRIMA di creare l'app
  final brightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final isSystemDark = brightness == Brightness.dark;

  runApp(MyApp(initialDarkMode: isSystemDark));
}

class MyApp extends StatefulWidget {
  final bool initialDarkMode;

  const MyApp({
    super.key,
    required this.initialDarkMode,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeManager _themeManager;
  bool _onboardingShown = false;
  bool _privacyTermsAccepted = false;
  bool _isLoadingInitialData = true;

  @override
  void initState() {
    super.initState();
    _themeManager = ThemeManager(initialDarkMode: widget.initialDarkMode);
    _checkOnboardingAndPrivacyStatus();
  }

  Future<void> _checkOnboardingAndPrivacyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingShown = prefs.getBool('onboarding_shown_v1') ?? false;
      _privacyTermsAccepted =
          prefs.getBool('privacy_terms_accepted_v1') ?? false;
      _isLoadingInitialData = false;
    });
  }

  @override
  void dispose() {
    _themeManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeManager,
      builder: (context, _) {
        if (_isLoadingInitialData) {
          return const CupertinoApp(
            home: CupertinoPageScaffold(
              child: Center(
                child: CupertinoActivityIndicator(),
              ),
            ),
          );
        }

        Widget initialRoute;
        final isAuthenticated =
            AppDependencies.authService?.isAuthenticated() ?? false;

        if (!_onboardingShown) {
          initialRoute = OnboardingPage(
            themeManager: _themeManager,
            onOnboardingComplete: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('onboarding_shown_v1', true);
              setState(() {
                _onboardingShown = true;
              });
            },
          );
        } else if (!_privacyTermsAccepted && isAuthenticated) {
          initialRoute = PrivacyTermsPage(
            themeManager: _themeManager,
            onAccepted: () async {
              final prefs = await SharedPreferences.getInstance();
              // Registra accettazione termini sul backend (best effort)
              try {
                await AppDependencies.authRepository.acceptTerms(version: 'v1');
              } catch (_) {
                // Se fallisce, continuiamo comunque a livello locale
              }
              await prefs.setBool('privacy_terms_accepted_v1', true);
              if (!mounted) return;
              setState(() {
                _privacyTermsAccepted = true;
              });
              // Dopo l'accettazione iniziale porta sempre alla Home
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (_) => HomePage(themeManager: _themeManager),
                ),
                (route) => false,
              );
            },
          );
        } else {
          initialRoute = HomePage(themeManager: _themeManager);
        }

        return CupertinoApp(
          title: 'NULL',
          theme: CupertinoThemeData(
            brightness:
                _themeManager.isDarkMode ? Brightness.dark : Brightness.light,
            primaryColor: const Color(0xFF007AFF),
          ),
          home: initialRoute,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
