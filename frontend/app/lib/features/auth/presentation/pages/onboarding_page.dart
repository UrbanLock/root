import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';

class OnboardingPage extends StatefulWidget {
  final ThemeManager themeManager;
  final VoidCallback onOnboardingComplete;

  const OnboardingPage({
    super.key,
    required this.themeManager,
    required this.onOnboardingComplete,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeManager,
      builder: (context, _) {
        final isDark = widget.themeManager.isDarkMode;

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      _buildOnboardingSlide(
                        isDark: isDark,
                        icon: CupertinoIcons.map_fill,
                        title: 'Trova il locker più vicino',
                        description:
                            'Visualizza sulla mappa tutte le postazioni disponibili e trova quella più comoda per te.',
                      ),
                      _buildOnboardingSlide(
                        isDark: isDark,
                        icon: CupertinoIcons.lock_fill,
                        title: 'Deposita o ritira oggetti',
                        description:
                            'Usa l\'app per aprire e chiudere le celle in modo sicuro, per i tuoi depositi o per ritirare ordini.',
                      ),
                      _buildOnboardingSlide(
                        isDark: isDark,
                        icon: CupertinoIcons.gift_fill,
                        title: 'Dona e condividi',
                        description:
                            'Contribuisci alla comunità donando oggetti che non usi più, dando loro una seconda vita.',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColors.primary(isDark)
                                  : AppColors
                                      .textSecondary(isDark)
                                      .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            if (_currentPage < 2) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeIn,
                              );
                            } else {
                              widget.onOnboardingComplete();
                            }
                          },
                          child: Text(
                            _currentPage < 2 ? 'Avanti' : 'Inizia',
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildOnboardingSlide({
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 100,
            color: AppColors.primary(isDark),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: AppTextStyles.title(isDark).copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: AppTextStyles.bodySecondary(isDark).copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
