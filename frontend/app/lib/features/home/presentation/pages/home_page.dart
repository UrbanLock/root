import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
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
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:app/features/home/presentation/widgets/profile_popup.dart';

class HomePage extends StatefulWidget {
  final ThemeManager themeManager;

  const HomePage({
    super.key,
    required this.themeManager,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
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
  
  // Controller per la mappa
  final MapController _mapController = MapController();
  
  // Servizio per la geolocalizzazione
  final Location _location = Location();
  bool _locationPermissionGranted = false;
  LatLng? _userLocation; // Posizione dell'utente
  
  // AnimationController per animazioni smooth
  late AnimationController _animationController;
  
  // Stato autenticazione (per ora semplice, poi si può migliorare)
  bool _isAuthenticated = false;
  bool _showProfilePopup = false;
  
  // Dati utente (per ora mock, poi da backend)
  String? _userName;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadLockers();
    _requestLocationPermissionAndZoom();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Metodo helper per animare lo zoom
  Future<void> _animateToLocation(LatLng target, double zoom) async {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;
    
    _animationController.reset();
    _animationController.forward();
    
    _animationController.addListener(() {
      final t = Curves.easeInOut.transform(_animationController.value);
      
      final lat = currentCenter.latitude + (target.latitude - currentCenter.latitude) * t;
      final lng = currentCenter.longitude + (target.longitude - currentCenter.longitude) * t;
      final currentZoomValue = currentZoom + (zoom - currentZoom) * t;
      
      _mapController.move(LatLng(lat, lng), currentZoomValue);
    });
    
    await _animationController.forward();
  }
  
  Future<void> _requestLocationPermissionAndZoom() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Controlla se il servizio di localizzazione è abilitato
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    // Controlla i permessi
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    if (permissionGranted == PermissionStatus.granted) {
      setState(() {
        _locationPermissionGranted = true;
      });
      
      // Ottieni la posizione e fai zoom automatico
      await _zoomToUserLocation();
    }
  }
  
  Future<void> _zoomToUserLocation() async {
    // Se abbiamo già la posizione salvata, usa quella (più veloce)
    if (_userLocation != null) {
      await _animateToLocation(_userLocation!, 15.0);
      return;
    }

    // Altrimenti richiedi i permessi se necessario
    if (!_locationPermissionGranted) {
      await _requestLocationPermissionAndZoom();
      if (!_locationPermissionGranted) {
        return;
      }
    }

    try {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final userLatLng = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        
        // Salva la posizione dell'utente
        setState(() {
          _userLocation = userLatLng;
        });
        
        // Zoom con animazione smooth
        await _animateToLocation(userLatLng, 15.0);
      }
    } catch (e) {
      // Se c'è un errore, mantieni la posizione di default (Trento)
      await _animateToLocation(
        const LatLng(MapConfig.centerLat, MapConfig.centerLng),
        13.0,
      );
    }
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
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(
                  MapConfig.centerLat,
                  MapConfig.centerLng,
                ),
                initialZoom: 13,
                onTap: (_, __) {
                  // Chiudi la tastiera quando si tocca la mappa
                  FocusScope.of(context).unfocus();
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
                // Marker posizione utente
                if (_userLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userLocation!,
                        width: 32,
                        height: 32,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Cerchio esterno (pulsante)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primary(isDark).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Cerchio medio
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.primary(isDark).withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Punto centrale
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.primary(isDark),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: CupertinoColors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
          // Pulsante posizione utente (floating, in basso a destra)
          // Posizionato prima del contenuto così il popup locker sarà sopra
          Positioned(
            right: 16,
            bottom: 100, // Sopra il footer
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: _zoomToUserLocation,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowColor(isDark).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      CupertinoIcons.location_fill,
                      color: AppColors.primary(isDark),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Pulsante "Accedi" (solo se non autenticato, posizionato sotto il profilo utente)
          if (!_isAuthenticated)
            Builder(
              builder: (context) {
                final safeAreaTop = MediaQuery.of(context).padding.top;
                final headerPaddingTop = 12.0;
                final headerPaddingBottom = 10.0;
                final headerContentHeight = 56.0; // Altezza del contenuto dell'header (logo + search + profilo)
                final spacing = 8.0; // Spazio tra header e pulsante
                
                // Calcola la posizione: sotto l'header, allineato a destra
                final topPosition = safeAreaTop + headerPaddingTop + headerContentHeight + headerPaddingBottom + spacing;
                
                return Positioned(
                  top: topPosition,
                  right: 16, // Allineato con il profilo utente (stesso padding dell'header)
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary(isDark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minSize: 0,
                          onPressed: () {
                            Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => LoginPage(
                                onLoginSuccess: (success) {
                                  setState(() {
                                    _isAuthenticated = success;
                                  });
                                },
                              ),
                            ),
                            );
                          },
                          child: const Text(
                            'Accedi',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Contenuto sopra la mappa
          GestureDetector(
            onTap: () {
              // Chiudi la tastiera quando si tocca fuori dalla barra di ricerca
              FocusScope.of(context).unfocus();
              // Chiudi anche il popup profilo se aperto
              if (_showProfilePopup) {
                setState(() {
                  _showProfilePopup = false;
                });
              }
            },
            child: Column(
              children: [
              // Header: logo e search+profilo sulla stessa riga
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 10,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Logo (quadrato grigio)
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: AppColors.searchBackground(isDark),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Barra di ricerca
                                            Expanded(
                                              child: CupertinoSearchTextField(
                                                placeholder: 'Cerca lockers...',
                                                backgroundColor: CupertinoColors.transparent,
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
                                                setState(() {
                                                  _showProfilePopup = !_showProfilePopup;
                                                });
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
                                    child: const Text(
                                      'Apri',
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
          ),
          // Popup profilo utente (posizionato alla fine per essere sopra tutto)
          if (_showProfilePopup)
            // Overlay per chiudere il popup quando si clicca fuori
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showProfilePopup = false;
                  });
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          if (_showProfilePopup)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12 + 56 + 10, // Sotto l'header
              right: 16, // Allineato con il pulsante profilo
                child: ProfilePopup(
                  isAuthenticated: _isAuthenticated,
                  userName: _userName,
                  onLoginTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => LoginPage(
                          onLoginSuccess: (success) {
                            setState(() {
                              _isAuthenticated = success;
                              if (success) {
                                // Mock: imposta dati utente dopo login
                                _userName = 'Mario Rossi';
                                _userEmail = 'mario.rossi@example.com';
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                  onLogoutTap: () {
                    setState(() {
                      _isAuthenticated = false;
                      _showProfilePopup = false;
                      _userName = null;
                      _userEmail = null;
                    });
                  },
                  onHistoryTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    // TODO: Naviga alla pagina storico utilizzi
                    _showComingSoonDialog(context, isDark, 'Storico utilizzi');
                  },
                  onActiveReservationsTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    // TODO: Naviga alla pagina prenotazioni attive
                    _showComingSoonDialog(context, isDark, 'Prenotazioni attive');
                  },
                  onDonateTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    // TODO: Naviga alla pagina donazione
                    _showComingSoonDialog(context, isDark, 'Donare un oggetto');
                  },
                  onHelpTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    // TODO: Naviga alla pagina aiuto
                    _showComingSoonDialog(context, isDark, 'Aiuto e supporto');
                  },
                ),
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
                          color: CupertinoColors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: CupertinoTabBar(
                          currentIndex: _currentIndex,
                          onTap: (index) {
                            setState(() {
                              _currentIndex = index;
                              _showCategoryFilters = false;
                            });
                            // Se si clicca su Home, reset zoom al default con animazione
                            if (index == 1) {
                              _animateToLocation(
                                const LatLng(MapConfig.centerLat, MapConfig.centerLng),
                                13.0,
                              );
                            }
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
  
  // Metodi helper per i dialog
  void _showComingSoonDialog(BuildContext context, bool isDark, String feature) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          feature,
          style: TextStyle(color: AppColors.text(isDark)),
        ),
        content: Text(
          'Questa funzionalità sarà disponibile a breve.',
          style: TextStyle(color: AppColors.textSecondary(isDark)),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  
  void _showAboutDialog(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          'Info app',
          style: TextStyle(color: AppColors.text(isDark)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NULL',
              style: TextStyle(
                color: AppColors.text(isDark),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Versione 1.0.0',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 16),
            Text(
              'Sistema di gestione lockers intelligenti per la città di Trento.',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Privacy'),
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Apri pagina privacy
            },
          ),
          CupertinoDialogAction(
            child: const Text('Termini'),
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Apri pagina termini
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
