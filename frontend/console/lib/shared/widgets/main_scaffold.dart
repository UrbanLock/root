import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/home_page.dart';
import 'package:console/reports_page.dart';

class MainScaffold extends StatefulWidget {
  final Widget body;
  final ThemeManager themeManager;
  final String? currentRoute;
  final String? title;
  final bool showBackButton;
  
  const MainScaffold({
    super.key,
    required this.body,
    required this.themeManager,
    this.currentRoute,
    this.title,
    this.showBackButton = false,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  String? _hoveredButton;

  void _navigateToRoute(String? route, BuildContext context) {
    if (route == null) return;
    
    // Se siamo già sulla route, non fare nulla
    if (widget.currentRoute == route) return;
    
    switch (route) {
      case 'home':
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(
            builder: (context) => HomePage(themeManager: widget.themeManager),
          ),
          (route) => false,
        );
        break;
      case 'reports':
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => ReportsPage(themeManager: widget.themeManager),
          ),
        );
        break;
    }
  }

  Widget _buildNavigationBar(bool isDark) {
    final buttons = [
      {'label': 'Home', 'icon': CupertinoIcons.house_fill, 'route': 'home'},
      {'label': 'Crea Locker', 'icon': CupertinoIcons.add_circled, 'route': null},
      {'label': 'Donazioni', 'icon': CupertinoIcons.heart_fill, 'route': null},
      {'label': 'Segnalazioni', 'icon': CupertinoIcons.exclamationmark_triangle_fill, 'route': 'reports'},
      {'label': 'Affitto Celle', 'icon': CupertinoIcons.calendar, 'route': null},
      {'label': 'Analytics', 'icon': CupertinoIcons.chart_bar_fill, 'route': null},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: buttons.map((button) {
          final isHovered = _hoveredButton == button['label'];
          final isActive = widget.currentRoute == button['route'];
          return Expanded(
            child: MouseRegion(
              onEnter: (_) {
                setState(() {
                  _hoveredButton = button['label'] as String;
                });
              },
              onExit: (_) {
                setState(() {
                  _hoveredButton = null;
                });
              },
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: () => _navigateToRoute(button['route'] as String?, context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isHovered || isActive
                        ? AppColors.primary.withOpacity(0.2)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        button['icon'] as IconData,
                        size: 18,
                        color: isHovered || isActive
                            ? AppColors.primary
                            : (isDark ? CupertinoColors.white : CupertinoColors.black),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          button['label'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isHovered || isActive ? FontWeight.bold : FontWeight.normal,
                            color: isHovered || isActive
                                ? AppColors.primary
                                : (isDark ? CupertinoColors.white : CupertinoColors.black),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.isDarkMode;
    
    return CupertinoPageScaffold(
      backgroundColor: isDark 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Menu di navigazione fisso
            _buildNavigationBar(isDark),
            
            // Titolo e pulsante indietro (se necessario)
            if (widget.title != null || widget.showBackButton)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.showBackButton)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Icon(
                          CupertinoIcons.back,
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                        ),
                      ),
                    if (widget.title != null) ...[
                      if (widget.showBackButton) const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? CupertinoColors.white : CupertinoColors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            
            // Contenuto della pagina
            Expanded(
              child: widget.body,
            ),
          ],
        ),
      ),
    );
  }
}

