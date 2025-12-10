import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

class ThemeManager extends ChangeNotifier with WidgetsBindingObserver {
  bool _isDarkMode;

  // Costruttore che accetta il tema iniziale dal sistema
  ThemeManager({bool? initialDarkMode}) 
      : _isDarkMode = initialDarkMode ?? false {
    // Ascolta i cambiamenti del tema di sistema
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isDarkMode => _isDarkMode;

  @override
  void didChangePlatformBrightness() {
    // Aggiorna quando il tema di sistema cambia
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final newIsDark = brightness == Brightness.dark;
    if (_isDarkMode != newIsDark) {
      _isDarkMode = newIsDark;
      notifyListeners();
    }
    super.didChangePlatformBrightness();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setTheme(bool isDark) {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

