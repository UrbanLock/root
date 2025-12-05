import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/notifications/notification_service.dart';
import 'package:app/features/home/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza il servizio di notifiche
  await NotificationService().initialize();
  
  // Leggi il tema di sistema PRIMA di creare l'app
  final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
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

  @override
  void initState() {
    super.initState();
    // Passa il tema di sistema al ThemeManager
    _themeManager = ThemeManager(initialDarkMode: widget.initialDarkMode);
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
        return CupertinoApp(
          title: 'NULL',
          theme: CupertinoThemeData(
            brightness: _themeManager.isDarkMode
                ? Brightness.dark
                : Brightness.light,
            primaryColor: const Color(0xFF007AFF),
          ),
          home: HomePage(themeManager: _themeManager),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
