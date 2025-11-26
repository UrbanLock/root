import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/features/home/presentation/pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeManager _themeManager = ThemeManager();

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
