import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/core/config/map_config.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/core/styles/app_colors.dart';
import 'package:app/core/styles/app_text_styles.dart';
import 'package:app/core/di/app_dependencies.dart';
import 'package:app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:app/features/settings/presentation/pages/settings_page.dart';
import 'package:app/features/lockers/domain/models/locker.dart';
import 'package:app/features/lockers/domain/models/locker_type.dart';
import 'package:app/features/lockers/domain/repositories/locker_repository.dart';

class HomePage extends StatefulWidget {
  final ThemeManager themeManager;

  const HomePage({
    super.key,
    required this.themeManager,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1; // Home selezionata di default
  Set<LockerType> _selectedFilters = {}; // Filtri attivi (vuoto = tutti)
  Locker? _selectedLocker; // Locker selezionato per i dettagli
  bool _showCategoryFilters = false; // Mostra filtri categoria nella ricerca
  
  // Stato per i lockers
  List<Locker> _lockers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  
  final LockerRepository _lockerRepository = AppDependencies.lockerRepository;

  @override
  void initState() {
    super.initState();
    _loadLockers();
  }

  Future<void> _loadLockers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lockers = await _lockerRepository.getLockers();
      setState(() {
        _lockers = lockers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento dei lockers: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchLockers(String query) async {
    setState(() {
      _searchQuery = query;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lockers = query.isEmpty
          ? await _lockerRepository.getLockers()
          : await _lockerRepository.searchLockers(query);
      
      setState(() {
        _lockers = lockers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nella ricerca: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _filterByType(LockerType type, bool isSelected) async {
    setState(() {
      if (isSelected) {
        _selectedFilters.remove(type);
      } else {
        _selectedFilters.add(type);
      }
      _isLoading = true;
    });

    try {
      List<Locker> lockers;
      
      if (_selectedFilters.isEmpty) {
        lockers = await _lockerRepository.getLockers();
      } else if (_selectedFilters.length == 1) {
        lockers = await _lockerRepository.getLockersByType(_selectedFilters.first);
      } else {
        // Filtro multiplo: carica tutti e filtra lato client
        final allLockers = await _lockerRepository.getLockers();
        lockers = allLockers
            .where((l) => _selectedFilters.contains(l.type))
            .toList();
      }
      
      setState(() {
        _lockers = lockers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel filtro: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Locker> get _filteredLockers {
    if (_selectedFilters.isEmpty) {
      return _lockers;
    }
    return _lockers.where((l) => _selectedFilters.contains(l.type)).toList();
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return NotificationsPage(themeManager: widget.themeManager);
      case 1:
        return _buildMapView();
      case 2:
        return SettingsPage(themeManager: widget.themeManager);
      default:
        return _buildMapView();
    }
  }

  Widget _buildMapView() {
    final isDark = widget.themeManager.isDarkMode;
    final filteredLockers = _filteredLockers;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(isDark),
      child: Stack(
        children: [
          // Mappa centrata su Trento
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(
                  MapConfig.centerLat,
                  MapConfig.centerLng,
                ),
                initialZoom: 13,
                onTap: (_, __) {
                  setState(() {
                    _selectedLocker = null;
                    _showCategoryFilters = false;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.getTileUrlTemplate(isDark),
                  subdomains: MapConfig.tileSubdomains,
                  userAgentPackageName: 'null.app/1.0',
                ),
                // Marker dei lockers
                if (!_isLoading && _errorMessage == null)
                  MarkerLayer(
                    markers: filteredLockers.map((locker) {
                      return Marker(
                        point: locker.position,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLocker = locker;
                              _showCategoryFilters = false;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary(isDark),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.card(isDark),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadowColor(isDark),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              locker.type.icon,
                              color: CupertinoColors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          // Overlay di loading
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: AppColors.overlayLoading(isDark),
                child: const Center(
                  child: CupertinoActivityIndicator(radius: 20),
                ),
              ),
            ),
          // Overlay di errore
          if (_errorMessage != null && !_isLoading)
            Positioned.fill(
              child: Container(
                color: AppColors.overlayError(isDark),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          size: 48,
                          color: CupertinoColors.systemRed,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(isDark),
                        ),
                        const SizedBox(height: 24),
                        CupertinoButton.filled(
                          onPressed: _loadLockers,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Contenuto sopra la mappa
          Column(
            children: [
              // Header: logo e search+profilo sulla stessa riga
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('NULL', style: AppTextStyles.logo(isDark)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(isDark),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Barra di ricerca
                                            Expanded(
                                              child: CupertinoSearchTextField(
                                                placeholder: 'Cerca lockers...',
                                                backgroundColor: AppColors
                                                    .searchBackground(isDark),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 8,
                                                  vertical: 6,
                                                ),
                                                prefixIcon: Icon(
                                                  CupertinoIcons.search,
                                                  size: 18,
                                                  color: AppColors.textSecondary(
                                                      isDark),
                                                ),
                                                style: TextStyle(
                                                  color: AppColors.text(isDark),
                                                ),
                                                placeholderStyle: TextStyle(
                                                  color: AppColors.textSecondary(
                                                      isDark),
                                                ),
                                                onChanged: (value) {
                                                  _searchLockers(value);
                                                },
                                                onTap: () {
                                                  setState(() {
                                                    _showCategoryFilters = true;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Pulsante per mostrare/nascondere filtri
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minSize: 0,
                                              onPressed: () {
                                                setState(() {
                                                  _showCategoryFilters =
                                                      !_showCategoryFilters;
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: _showCategoryFilters
                                                      ? AppColors.primary(isDark)
                                                      : AppColors.surface(
                                                          isDark),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  _showCategoryFilters
                                                      ? CupertinoIcons
                                                          .chevron_up
                                                      : CupertinoIcons
                                                          .chevron_down,
                                                  size: 18,
                                                  color: _showCategoryFilters
                                                      ? CupertinoColors.white
                                                      : AppColors.textSecondary(
                                                          isDark),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Profilo utente
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              minSize: 32,
                                              child: Icon(
                                                CupertinoIcons
                                                    .person_crop_circle,
                                                size: 30,
                                                color: AppColors.logoText(
                                                    isDark),
                                              ),
                                              onPressed: () {
                                                // TODO: azione profilo utente
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Filtri categoria (mostrati dentro la barra di ricerca)
                                      if (_showCategoryFilters)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 0, 12, 10),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: LockerType.values
                                                  .map((type) {
                                                final isSelected =
                                                    _selectedFilters
                                                        .contains(type);
                                                return Padding(
                                                  padding: const EdgeInsets.only(
                                                      right: 8),
                                                  child: CupertinoButton(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    minSize: 0,
                                                    onPressed: () {
                                                      _filterByType(
                                                          type, isSelected);
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? AppColors.primary(
                                                                isDark)
                                                            : AppColors.surface(
                                                                isDark),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? AppColors
                                                                  .primary(
                                                                      isDark)
                                                              : AppColors
                                                                  .borderSecondary(
                                                                      isDark),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            type.icon,
                                                            size: 16,
                                                            color: isSelected
                                                                ? CupertinoColors
                                                                    .white
                                                                : AppColors.text(
                                                                    isDark),
                                                          ),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                            type.label,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: isSelected
                                                                  ? CupertinoColors
                                                                      .white
                                                                  : AppColors
                                                                      .text(
                                                                          isDark),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Card dettagli locker se selezionato
              if (_selectedLocker != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface(isDark),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.iconBackground(isDark),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _selectedLocker!.type.icon,
                                      color: AppColors.primary(isDark),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedLocker!.name,
                                          style: AppTextStyles.title(isDark),
                                        ),
                                        Text(
                                          _selectedLocker!.type.label,
                                          style: AppTextStyles.bodySecondary(
                                              isDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minSize: 0,
                                    onPressed: () {
                                      setState(() {
                                        _selectedLocker = null;
                                      });
                                    },
                                    child: const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedLocker!.description != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _selectedLocker!.description!,
                                  style: AppTextStyles.bodySecondary(isDark),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Disponibilità',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary(
                                                isDark),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_selectedLocker!.availableCells}/${_selectedLocker!.totalCells} celle',
                                          style: AppTextStyles.body(isDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    color: AppColors.primary(isDark),
                                    borderRadius: BorderRadius.circular(20),
                                    onPressed: () {
                                      // TODO: apri dettagli locker
                                    },
                                    child: const Text('Apri'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                // Card informativa sopra la bottom bar (se nessun locker selezionato)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface(isDark),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.location_solid,
                                color: AppColors.primary(isDark),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isLoading
                                      ? 'Caricamento lockers...'
                                      : 'Area corrente: Trento\n${_lockers.length} lockers disponibili. Tocca un marker per i dettagli.',
                                  style: TextStyle(
                                    color: AppColors.text(isDark),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.isDarkMode;
    
    return ListenableBuilder(
      listenable: widget.themeManager,
      builder: (context, _) {
        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(isDark),
          child: Stack(
            children: [
              // Contenuto della pagina corrente
              Positioned.fill(
                bottom: 80, // Spazio per il footer
                child: _getCurrentPage(),
              ),
              // Footer sempre visibile in basso
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.bottomBarBackground(isDark),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: CupertinoTabBar(
                          currentIndex: _currentIndex,
                          onTap: (index) {
                            setState(() {
                              _currentIndex = index;
                              _showCategoryFilters = false;
                            });
                          },
                          items: const [
                            BottomNavigationBarItem(
                              icon: Icon(CupertinoIcons.bell),
                              label: 'Notifiche',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(CupertinoIcons.home),
                              label: 'Home',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(CupertinoIcons.settings),
                              label: 'Impostazioni',
                            ),
                          ],
                          backgroundColor: CupertinoColors.transparent,
                          activeColor: AppColors.bottomBarActive(isDark),
                          inactiveColor: AppColors.bottomBarInactive(isDark),
                          border: const Border(
                            top: BorderSide(
                              color: CupertinoColors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
