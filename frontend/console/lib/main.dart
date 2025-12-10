import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
          title: 'Console',
          theme: CupertinoThemeData(
            brightness: _themeManager.isDarkMode
                ? Brightness.dark
                : Brightness.light,
            primaryColor: const Color(0xFF007AFF),
          ),
          home: LoginPage(themeManager: _themeManager),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
