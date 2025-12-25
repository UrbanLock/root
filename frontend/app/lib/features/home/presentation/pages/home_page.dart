import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:app/features/home/presentation/pages/locker_detail_page.dart';
import 'package:app/features/profile/presentation/pages/history_page.dart';
import 'package:app/features/profile/presentation/pages/active_reservations_page.dart';
import 'package:app/features/profile/presentation/pages/donate_page.dart';
import 'package:app/features/profile/presentation/pages/help_page.dart';
import 'package:app/features/reports/presentation/pages/reports_list_page.dart';
import 'package:app/core/utils/responsive_utils.dart';
import 'package:app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:app/features/notifications/data/repositories/notification_repository.dart';

class HomePage extends StatefulWidget {
  final ThemeManager themeManager;

  const HomePage({
    super.key,
    required this.themeManager,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 1; // Home selezionata di default
  Set<LockerType> _selectedFilters = {}; // Filtri attivi (vuoto = tutti)
  Locker? _selectedLocker; // Locker selezionato per i dettagli
  bool _showCategoryFilters = false; // Mostra filtri categoria nella ricerca
  Timer? _notificationsTimer;
  Timer? _searchDebounce;
  List<Locker> _allLockers = [];
  List<Marker> _cachedLockerMarkers = [];
  String _cachedLockerMarkersKey = '';
  StreamSubscription<LocationData>? _locationSub;
  Timer? _locationDebounce;
  DateTime? _lastMapGestureAt;
  VoidCallback? _mapAnimationListener;
  bool _isMapAnimating = false;
  final Distance _distance = const Distance();
  bool _didAutoCenterToUser = false;

  static const String _lockersCacheKey = 'lockers_cache_v1';
  static const String _userLocationLatKey = 'user_location_lat_v1';
  static const String _userLocationLngKey = 'user_location_lng_v1';
  
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

  // Stato notifiche
  int _unreadNotificationsCount = 0;
  final NotificationRepository _notificationRepository =
      AppDependencies.notificationRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initializeAuthState();
    _restoreCachedLockers().then((_) {
      // Se abbiamo cache, non blocchiamo la UI con overlay pesante al primo frame
      _loadLockers(showLoading: _lockers.isEmpty);
    });
    _requestLocationPermissionAndZoom();
    _loadUnreadNotificationsCount();

    // Polling periodico per aggiornare il badge notifiche
    _notificationsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_isAuthenticated) {
          _loadUnreadNotificationsCount();
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ricarica il contatore quando la pagina diventa visibile
    _loadUnreadNotificationsCount();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationsTimer?.cancel();
    _searchDebounce?.cancel();
    _locationDebounce?.cancel();
    _locationSub?.cancel();
    if (_mapAnimationListener != null) {
      _animationController.removeListener(_mapAnimationListener!);
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quando l'app va in background, verifica se ci sono celle aperte
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _checkOpenCellsAndNotify();
    }
    if (state == AppLifecycleState.resumed && _isAuthenticated) {
      _loadUnreadNotificationsCount();
    }
    if (state == AppLifecycleState.resumed) {
      // Quando torniamo in foreground aggiorniamo subito la posizione (senza “saltare”)
      _startLocationStreamIfPossible();
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    if (!_isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _unreadNotificationsCount = 0;
      });
      return;
    }
    try {
      final count = await _notificationRepository.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      // Ignora errori
    }
  }

  Future<void> _checkOpenCellsAndNotify() async {
    // TODO: Quando il backend sarà pronto, caricare celle attive dal repository
    // Per ora, questa funzione è un placeholder
    // In produzione, verificheremo se ci sono celle aperte e notificheremo l'utente
  }

  /// Inizializza lo stato di autenticazione e i dati utente
  Future<void> _initializeAuthState() async {
    final authService = AppDependencies.authService;
    final authRepository = AppDependencies.authRepository;

    final isAuth = authService?.isAuthenticated() ?? false;

    if (isAuth && authRepository != null) {
      try {
        final user = await authRepository.getMe();
        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
          _userName = user.nomeCompleto;
          _userEmail = user.email;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _userName = null;
        _userEmail = null;
      });
    }
  }
  
  // Metodo helper per animare lo zoom
  Future<void> _animateToLocation(LatLng target, double zoom) async {
    // Evita accumulo di listeners (causa lag) e doppie animazioni
    if (_isMapAnimating) {
      _animationController.stop();
      _isMapAnimating = false;
    }
    if (_mapAnimationListener != null) {
      _animationController.removeListener(_mapAnimationListener!);
      _mapAnimationListener = null;
    }

    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;

    // Se siamo già praticamente lì, non animare
    final meters = _distance.as(
      LengthUnit.Meter,
      currentCenter,
      target,
    );
    if (meters < 2 && (currentZoom - zoom).abs() < 0.02) {
      _mapController.move(target, zoom);
      return;
    }

    _animationController.duration = const Duration(milliseconds: 650);
    _animationController.reset();

    _mapAnimationListener = () {
      final t = Curves.easeInOutCubic.transform(_animationController.value);
      final lat =
          currentCenter.latitude + (target.latitude - currentCenter.latitude) * t;
      final lng =
          currentCenter.longitude + (target.longitude - currentCenter.longitude) * t;
      final z = currentZoom + (zoom - currentZoom) * t;
      _mapController.move(LatLng(lat, lng), z);
    };

    _isMapAnimating = true;
    _animationController.addListener(_mapAnimationListener!);
    try {
      await _animationController.forward();
    } finally {
      _isMapAnimating = false;
      if (_mapAnimationListener != null) {
        _animationController.removeListener(_mapAnimationListener!);
        _mapAnimationListener = null;
      }
    }
  }
  
  Future<void> _requestLocationPermissionAndZoom() async {
    // 1) Ripristina subito l'ultima posizione nota (UX immediata)
    await _restoreCachedUserLocationAndMoveMap();

    try {
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
        
        // Attiva tracking marker utente (senza ricentrare la mappa)
        _startLocationStreamIfPossible();
        // Auto-centering SOLO una volta e solo se l'utente non ha già interagito con la mappa
        await _zoomToUserLocation(force: false);
      }
    } catch (e) {
      // Se il plugin location non è disponibile (es. su web o emulatore senza servizi),
      // ignora l'errore e continua senza geolocalizzazione
      debugPrint('Errore servizio location: $e');
      // Mantieni la posizione di default (Trento)
    }
  }
  
  Future<void> _zoomToUserLocation({required bool force}) async {
    try {
      if (!_locationPermissionGranted) return;

      if (!force) {
        // Non ricentrare automaticamente se l'utente ha già mosso la mappa
        if (_lastMapGestureAt != null) return;
        if (_didAutoCenterToUser) return;

        // Ricentra solo se siamo ancora vicino al centro/zoom di default (prima apertura app)
        final metersFromDefault = _distance.as(
          LengthUnit.Meter,
          _mapController.camera.center,
          const LatLng(MapConfig.centerLat, MapConfig.centerLng),
        );
        if (metersFromDefault > 120) return;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final userLatLng = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        
        await _updateUserLocation(userLatLng, animate: false);
        
        // Zoom con animazione smooth
        await _animateToLocation(userLatLng, MapConfig.userLocationZoom);
        _didAutoCenterToUser = true;
      }
    } catch (e) {
      // Se c'è un errore (plugin non disponibile, permessi negati, ecc.),
      // mantieni la posizione di default (Trento)
      debugPrint('Errore ottenimento posizione: $e');
      await _animateToLocation(
        const LatLng(MapConfig.centerLat, MapConfig.centerLng),
        MapConfig.defaultZoom,
      );
    }
  }

  Future<void> _loadLockers({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final lockers = await _lockerRepository.getLockers();
      setState(() {
        _allLockers = lockers;
        _applyLocalFilters();
        _isLoading = false;
      });
      await _saveLockersCache(lockers);
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento dei lockers: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreCachedLockers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lockersCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      final lockers = decoded
          .map((e) => Locker.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _allLockers = lockers;
        _applyLocalFilters();
        // non forziamo _isLoading=false qui: ci pensa _loadLockers(showLoading: _lockers.isEmpty)
      });
    } catch (_) {
      // ignora cache corrotta
    }
  }

  Future<void> _saveLockersCache(List<Locker> lockers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = lockers
          .map((l) => {
                'id': l.id,
                'name': l.name,
                'position': {'lat': l.position.latitude, 'lng': l.position.longitude},
                // LockerType.fromJson usa stringhe backend (sportivi/personali/...), non il nome enum
                'type': l.type.label.toLowerCase().replaceAll('-', ''),
                'totalCells': l.totalCells,
                'availableCells': l.availableCells,
                'isActive': l.isActive,
                'description': l.description,
              })
          .toList();
      await prefs.setString(_lockersCacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  void _applyLocalFilters() {
    final q = _searchQuery.trim().toLowerCase();
    final hasQuery = q.isNotEmpty;

    final filtered = _allLockers.where((locker) {
      final typeOk = _selectedFilters.isEmpty || _selectedFilters.contains(locker.type);
      if (!typeOk) return false;

      if (!hasQuery) return true;
      final nameMatch = locker.name.toLowerCase().contains(q);
      final descMatch = (locker.description ?? '').toLowerCase().contains(q);
      return nameMatch || descMatch;
    }).toList();

    _lockers = filtered;
  }

  String _formatDistance(double meters) {
    if (meters < 0) return '';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  double? _distanceToLockerMeters(Locker locker) {
    final user = _userLocation;
    if (user == null) return null;
    return _distance.as(LengthUnit.Meter, user, locker.position);
  }

  Color _availabilityColor(bool isDark, int available, int total) {
    if (total <= 0) return AppColors.textSecondary(isDark);
    final ratio = available / total;
    if (available == 0) return CupertinoColors.systemRed;
    if (ratio < 0.25) return CupertinoColors.systemOrange;
    return CupertinoColors.systemGreen;
  }

  Future<void> _openDirections(Locker locker) async {
    final lat = locker.position.latitude;
    final lng = locker.position.longitude;
    final name = Uri.encodeComponent(locker.name);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng($name)');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _applyLocalFilters();
      });
    });
  }

  List<Marker> _buildLockerMarkers({
    required List<Locker> lockers,
    required bool isDark,
    required String selectedLockerId,
  }) {
    // Cache markers per evitare rebuild pesanti su ogni setState (mappa più smooth)
    final idsKey = lockers.map((l) => l.id).join('|');
    final key = '${isDark ? 'dark' : 'light'}::$idsKey::sel=$selectedLockerId';
    if (key == _cachedLockerMarkersKey) {
      return _cachedLockerMarkers;
    }

    final markers = lockers.map((locker) {
      return Marker(
        point: locker.position,
        width: 50,
        height: 50,
        child: RepaintBoundary(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedLocker = locker;
                _showCategoryFilters = false;
              });
            },
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              scale: selectedLockerId == locker.id ? 1.08 : 1.0,
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
                      color: AppColors.shadowColor(isDark).withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
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
          ),
        ),
      );
    }).toList();

    _cachedLockerMarkersKey = key;
    _cachedLockerMarkers = markers;
    return markers;
  }

  Future<void> _restoreCachedUserLocationAndMoveMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_userLocationLatKey);
      final lng = prefs.getDouble(_userLocationLngKey);
      if (lat == null || lng == null) return;
      final cached = LatLng(lat, lng);
      if (!mounted) return;
      setState(() {
        _userLocation = cached;
      });
      // Move immediato (senza animazione) per evitare “salti” al primo frame
      _mapController.move(cached, _mapController.camera.zoom);
    } catch (_) {}
  }

  Future<void> _persistUserLocation(LatLng loc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_userLocationLatKey, loc.latitude);
      await prefs.setDouble(_userLocationLngKey, loc.longitude);
    } catch (_) {}
  }

  Future<void> _updateUserLocation(LatLng newLoc, {required bool animate}) async {
    final old = _userLocation;
    // Aggiorna marker solo se cambia davvero (riduce setState e repaint)
    if (old != null) {
      final meters = _distance.as(LengthUnit.Meter, old, newLoc);
      if (meters < 8) return; // soglia anti-jitter
    }

    if (!mounted) return;
    setState(() {
      _userLocation = newLoc;
    });
    await _persistUserLocation(newLoc);

    // Se l'utente sta interagendo con la mappa, non forzare l'animazione
    final gestureAt = _lastMapGestureAt;
    final recentlyGesturing =
        gestureAt != null && DateTime.now().difference(gestureAt) < const Duration(seconds: 2);
    if (!animate || recentlyGesturing) return;

    // Non cambiare zoom automaticamente durante tracking; solo centra con animazione leggera
    await _animateToLocation(newLoc, _mapController.camera.zoom);
  }

  void _startLocationStreamIfPossible() {
    if (!_locationPermissionGranted) return;
    if (_locationSub != null) return;

    _locationSub = _location.onLocationChanged.listen((data) {
      final lat = data.latitude;
      final lng = data.longitude;
      if (lat == null || lng == null) return;
      final loc = LatLng(lat, lng);

      // Debounce: evita aggiornamenti troppo frequenti (riduce lag)
      _locationDebounce?.cancel();
      _locationDebounce = Timer(const Duration(milliseconds: 600), () {
        // IMPORTANT: non ricentrare la mappa automaticamente (evita "salti" di focus).
        // Aggiorniamo solo il marker utente; il ricentro avviene solo su azione esplicita
        // (pulsante posizione o prima richiesta posizione).
        _updateUserLocation(loc, animate: false);
      });
    });
  }

  Future<void> _searchLockers(String query) async {
    // Deprecated: mantenuto per compatibilità, ora usiamo solo filtro locale con debounce.
    _onSearchChanged(query);
  }

  Future<void> _filterByType(LockerType type, bool isSelected) async {
    // Premium UX: filtri istantanei (solo locale, niente fetch) e senza overlay blocante
    setState(() {
      if (isSelected) {
        _selectedFilters.remove(type);
      } else {
        _selectedFilters.add(type);
      }
      _applyLocalFilters();
    });
  }

  List<Locker> get _filteredLockers {
    // Ora _lockers è già filtrata localmente (query + filtri)
    return _lockers;
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        if (!_isAuthenticated) {
          return _buildNotificationsLockedPage();
        }
        return NotificationsPage(
          themeManager: widget.themeManager,
          onNotificationsUpdated: _loadUnreadNotificationsCount,
        );
      case 1:
        return _buildMapView();
      case 2:
        return SettingsPage(
          themeManager: widget.themeManager,
          isAuthenticated: _isAuthenticated,
          onAuthenticationChanged: (isAuthenticated) {
            setState(() {
              _isAuthenticated = isAuthenticated;
            });
          },
        );
      default:
        return _buildMapView();
    }
  }

  Widget _buildNotificationsLockedPage() {
    final isDark = widget.themeManager.isDarkMode;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(isDark),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.bell,
                size: 64,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(height: 16),
              Text(
                'Accedi per vedere le tue notifiche',
                style: AppTextStyles.body(isDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _showLoginForNotifications,
                child: const Text('Accedi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLoginForNotifications() async {
    final shouldLogin = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Accesso richiesto'),
        content: const Text(
          'Per accedere alle notifiche devi effettuare l\'accesso.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accedi'),
          ),
        ],
      ),
    );

    if (shouldLogin != true) return;

    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => LoginPage(
          themeManager: widget.themeManager,
          onLoginSuccess: (success) async {
            if (!mounted) return;
            if (success) {
              await _initializeAuthState();
              await _loadUnreadNotificationsCount();
            }
          },
        ),
      ),
    );
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
                initialZoom: MapConfig.defaultZoom,
                minZoom: MapConfig.minZoom,
                maxZoom: MapConfig.maxZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _lastMapGestureAt = DateTime.now();
                  }
                },
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
                  maxZoom: MapConfig.maxZoom,
                  minZoom: MapConfig.minZoom,
                  tileProvider: NetworkTileProvider(),
                  errorTileCallback: (tile, error, stackTrace) {
                    // Gestisce errori di caricamento tile (es. senza internet)
                    // Log dell'errore per debug (solo in modalità debug)
                    debugPrint('Errore caricamento tile: $error');
                  },
                ),
                // Marker dei lockers
                if (!_isLoading && _errorMessage == null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: MarkerLayer(
                      key: ValueKey<String>(
                        '${isDark ? 'd' : 'l'}-${filteredLockers.length}-${_selectedLocker?.id ?? ''}',
                      ),
                      markers: _buildLockerMarkers(
                        lockers: filteredLockers,
                        isDark: isDark,
                        selectedLockerId: _selectedLocker?.id ?? '',
                      ),
                    ),
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
          if (_isLoading && _allLockers.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: AppColors.overlayLoading(isDark).withOpacity(0.55),
                  child: const Center(
                    child: CupertinoActivityIndicator(radius: 20),
                  ),
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
                    onPressed: () => _zoomToUserLocation(force: true),
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
                                  themeManager: widget.themeManager,
                                  onLoginSuccess: (success) async {
                                    if (!mounted) return;
                                    if (success) {
                                      await _initializeAuthState();
                                      await _loadUnreadNotificationsCount();
                                    }
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
                                                  _onSearchChanged(value);
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
              // Card bottom premium: transizione smooth tra "info" e "locker selezionato"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: _selectedLocker != null
                      ? ClipRRect(
                          key: ValueKey<String>('selected-${_selectedLocker!.id}'),
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
                                    // Popup minimal: titolo + tipo + chiudi
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedLocker!.name,
                                                style: AppTextStyles.title(isDark).copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _selectedLocker!.type.label,
                                                style: AppTextStyles.bodySecondary(isDark).copyWith(
                                                  fontSize: 13,
                                                ),
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
                                    const SizedBox(height: 10),
                                    // Info essenziali: distanza + disponibilità
                                    Builder(
                                      builder: (_) {
                                        final distMeters = _distanceToLockerMeters(_selectedLocker!);
                                        final distLabel = distMeters == null ? null : _formatDistance(distMeters);
                                        final available = _selectedLocker!.availableCells;
                                        final total = _selectedLocker!.totalCells;
                                        final color = _availabilityColor(isDark, available, total);
                                        final availabilityText = total > 0
                                            ? '$available/$total disponibili'
                                            : '$available disponibili';

                                        return Row(
                                          children: [
                                            if (distLabel != null) ...[
                                              Icon(
                                                CupertinoIcons.location,
                                                size: 14,
                                                color: AppColors.textSecondary(isDark),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                distLabel,
                                                style: AppTextStyles.bodySecondary(isDark).copyWith(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: color.withOpacity(0.22),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(CupertinoIcons.lock_fill, size: 14, color: color),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    availabilityText,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: CupertinoButton.filled(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            CupertinoPageRoute(
                                              builder: (context) => LockerDetailPage(
                                                themeManager: widget.themeManager,
                                                locker: _selectedLocker!,
                                                isAuthenticated: _isAuthenticated,
                                                onAuthenticationChanged: (isAuthenticated) {
                                                  setState(() {
                                                    _isAuthenticated = isAuthenticated;
                                                  });
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(CupertinoIcons.chevron_right, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Dettagli',
                                              style: TextStyle(
                                                color: CupertinoColors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : ClipRRect(
                          key: const ValueKey<String>('info-card'),
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
            Builder(
              builder: (context) {
                final safeAreaTop = MediaQuery.of(context).padding.top;
                final screenHeight = MediaQuery.of(context).size.height;
                // Calcola dinamicamente l'altezza dell'header
                final headerContentHeight = (screenHeight * 0.08).clamp(56.0, 80.0);
                final headerPaddingTop = 12.0;
                final headerPaddingBottom = 10.0;
                final spacing = 10.0;
                
                return Positioned(
                  top: safeAreaTop + headerPaddingTop + headerContentHeight + headerPaddingBottom + spacing,
                  right: 16, // Allineato con il pulsante profilo
                  child: ProfilePopup(
                    themeManager: widget.themeManager,
                    isAuthenticated: _isAuthenticated,
                    userName: _userName,
                    onLoginTap: () {
                      setState(() {
                        _showProfilePopup = false;
                      });
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => LoginPage(
                            themeManager: widget.themeManager,
                            onLoginSuccess: (success) async {
                              if (!mounted) return;
                              if (success) {
                                await _initializeAuthState();
                                await _loadUnreadNotificationsCount();
                              }
                            },
                          ),
                        ),
                      );
                    },
                    onLogoutTap: () async {
                      final authRepository = AppDependencies.authRepository;
                      final authService = AppDependencies.authService;

                      // 1. Chiama sempre l'API di logout lato backend (se disponibile)
                      try {
                        await authRepository?.logout();
                      } catch (_) {
                        // Ignora errori di logout (token scaduto, rete assente, ecc.)
                      }

                      // 2. Pulisci i token locali (se servizio disponibile)
                      await authService?.clearTokens();

                      // 3. Resetta l'accettazione di privacy/termini
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('privacy_terms_accepted_v1');

                      // 4. Aggiorna lo stato UI
                      if (!mounted) return;
                      setState(() {
                        _isAuthenticated = false;
                        _showProfilePopup = false;
                        _userName = null;
                        _userEmail = null;
                      });
                      await _loadUnreadNotificationsCount();
                    },
                  onHistoryTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => HistoryPage(
                          themeManager: widget.themeManager,
                        ),
                      ),
                    );
                  },
                  onActiveReservationsTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => ActiveReservationsPage(
                          themeManager: widget.themeManager,
                        ),
                      ),
                    );
                  },
                  onDonateTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => DonatePage(
                          themeManager: widget.themeManager,
                        ),
                      ),
                    );
                  },
                  onHelpTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => HelpPage(
                          themeManager: widget.themeManager,
                        ),
                      ),
                    );
                  },
                  onReportsTap: () {
                    setState(() {
                      _showProfilePopup = false;
                    });
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => ReportsListPage(
                          themeManager: widget.themeManager,
                        ),
                      ),
                    );
                  },
                ),
              );
              },
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
                            // Blocca accesso alle notifiche se non autenticato
                            if (index == 0 && !_isAuthenticated) {
                              _showLoginForNotifications();
                              return;
                            }
                            setState(() {
                              _currentIndex = index;
                              _showCategoryFilters = false;
                            });
                            // Se si clicca su Home, reset zoom al default con animazione
                            if (index == 1) {
                              _animateToLocation(
                                const LatLng(MapConfig.centerLat, MapConfig.centerLng),
                                MapConfig.defaultZoom,
                              );
                              // L'utente ha scelto esplicitamente dove guardare: non auto-centrare più
                              _lastMapGestureAt = DateTime.now();
                            }
                          },
                          items: [
                            BottomNavigationBarItem(
                              icon: Stack(
                                children: [
                                  const Icon(CupertinoIcons.bell),
                                  if (_isAuthenticated && _unreadNotificationsCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: CupertinoColors.systemRed,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          _unreadNotificationsCount > 99
                                              ? '99+'
                                              : '$_unreadNotificationsCount',
                                          style: const TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              label: 'Notifiche',
                            ),
                            const BottomNavigationBarItem(
                              icon: Icon(CupertinoIcons.home),
                              label: 'Home',
                            ),
                            const BottomNavigationBarItem(
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
