import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';

class MainNavigationBar extends StatefulWidget {
  final ThemeManager themeManager;
  final String? currentRoute;
  final Function(String)? onNavigate;
  
  const MainNavigationBar({
    super.key,
    required this.themeManager,
    this.currentRoute,
    this.onNavigate,
  });

  @override
  State<MainNavigationBar> createState() => _MainNavigationBarState();
}

class _MainNavigationBarState extends State<MainNavigationBar> {
  String? _hoveredButton;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.isDarkMode;
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
                onPressed: () {
                  final route = button['route'] as String?;
                  if (route != null && widget.onNavigate != null) {
                    widget.onNavigate!(route);
                  }
                },
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
}
