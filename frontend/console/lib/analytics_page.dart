import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/features/analytics/domain/models/analytics_data.dart';
import 'package:console/features/analytics/data/mock_analytics_data.dart';
import 'package:console/features/lockers/domain/models/locker_type.dart';
import 'package:console/core/api/reporting_service.dart';

class AnalyticsPage extends StatefulWidget {
  final ThemeManager themeManager;
  
  const AnalyticsPage({super.key, required this.themeManager});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  // View mode: 'hourly', 'category', 'timeSlot', 'parkRanking', 'lockerRanking'
  String _currentView = 'hourly';
  LockerType? _selectedCategory;
  String? _selectedTimeSlot;
  String? _selectedPark;
  
  // Dati reali dal backend
  List<HourlyAffluence> _hourlyData = [];
  List<CategoryAffluence> _categoryData = [];
  List<TimeSlotCategoryData> _timeSlotData = [];
  Map<LockerType, List<ZoneUsage>> _zoneUsageByCategory = {};
  Map<String, List<LockerUsage>> _lockerUsageByZone = {};
  
  // Stato loading
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = 'mese'; // 'giorno', 'settimana', 'mese', 'anno'
  
  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Carica report utilizzo
      final usageReport = await ReportingService.getUsageReport(periodo: _selectedPeriod);
      
      if (usageReport['success'] == true) {
        final data = usageReport['data'] as Map<String, dynamic>;
        
        // Mappa perFasciaOraria a HourlyAffluence
        final perFasciaOraria = data['perFasciaOraria'] as List<dynamic>? ?? [];
        _hourlyData = _mapFasciaOrariaToHourly(perFasciaOraria);
        
        // Mappa perTipologia a CategoryAffluence
        final perTipologia = data['perTipologia'] as List<dynamic>? ?? [];
        _categoryData = _mapTipologiaToCategory(perTipologia);
        
        // Mappa perPostazione a ZoneUsage (raggruppato per tipo)
        final perPostazione = data['perPostazione'] as List<dynamic>? ?? [];
        _zoneUsageByCategory = await _mapPostazioneToZoneUsage(perPostazione, perTipologia);
        
        // Mappa perFasciaOraria a TimeSlotCategoryData
        _timeSlotData = _mapFasciaOrariaToTimeSlotCategory(perFasciaOraria, perTipologia);
        
        // Carica parchi popolari per locker ranking
        final popularParks = await ReportingService.getPopularParks(periodo: _selectedPeriod, limit: 50);
        if (popularParks['success'] == true) {
          final parksData = popularParks['data']['parks'] as List<dynamic>? ?? [];
          _lockerUsageByZone = _mapParksToLockerUsage(parksData);
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Errore durante il caricamento dei dati analytics: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Errore durante il caricamento dei dati: ${e.toString()}';
        // Usa dati mock come fallback
        _hourlyData = mockHourlyAffluence;
        _categoryData = mockCategoryAffluence;
        _timeSlotData = mockTimeSlotCategoryData;
        _zoneUsageByCategory = mockZoneUsageByCategory;
        _lockerUsageByZone = mockLockerUsageByZone;
      });
    }
  }

  // Mappa fascia oraria backend (00-06, 06-12, ecc.) a dati orari (0-23)
  List<HourlyAffluence> _mapFasciaOrariaToHourly(List<dynamic> perFasciaOraria) {
    final hourlyMap = <int, int>{};
    
    for (var fascia in perFasciaOraria) {
      final fasciaStr = fascia['fascia'] as String? ?? '';
      final count = fascia['count'] as int? ?? 0;
      
      // Distribuisci il count tra le ore della fascia
      List<int> hours;
      if (fasciaStr == '00-06') {
        hours = [0, 1, 2, 3, 4, 5];
      } else if (fasciaStr == '06-12') {
        hours = [6, 7, 8, 9, 10, 11];
      } else if (fasciaStr == '12-18') {
        hours = [12, 13, 14, 15, 16, 17];
      } else if (fasciaStr == '18-24') {
        hours = [18, 19, 20, 21, 22, 23];
      } else {
        continue;
      }
      
      // Distribuisci uniformemente il count tra le ore
      final countPerHour = (count / hours.length).ceil();
      for (var hour in hours) {
        hourlyMap[hour] = (hourlyMap[hour] ?? 0) + countPerHour;
      }
    }
    
    // Crea lista di HourlyAffluence per tutte le 24 ore
    return List.generate(24, (hour) {
      return HourlyAffluence(
        hour: hour,
        count: hourlyMap[hour] ?? 0,
      );
    });
  }

  // Mappa tipologia backend a CategoryAffluence
  List<CategoryAffluence> _mapTipologiaToCategory(List<dynamic> perTipologia) {
    return perTipologia.map((item) {
      final tipologiaStr = item['tipologia'] as String? ?? 'personali';
      final count = item['count'] as int? ?? 0;
      
      // Mappa stringa backend a LockerType
      LockerType category;
      switch (tipologiaStr) {
        case 'sportivi':
          category = LockerType.sportivi;
          break;
        case 'personali':
          category = LockerType.personali;
          break;
        case 'petFriendly':
          category = LockerType.petFriendly;
          break;
        case 'commerciali':
          category = LockerType.commerciali;
          break;
        case 'cicloturistici':
          category = LockerType.cicloturistici;
          break;
        default:
          category = LockerType.personali;
      }
      
      return CategoryAffluence(
        category: category,
        count: count,
      );
    }).toList();
  }

  // Mappa postazione a ZoneUsage raggruppato per categoria
  Future<Map<LockerType, List<ZoneUsage>>> _mapPostazioneToZoneUsage(
    List<dynamic> perPostazione,
    List<dynamic> perTipologia,
  ) async {
    final result = <LockerType, List<ZoneUsage>>{};
    
    // Inizializza tutte le categorie con liste vuote
    for (var category in LockerType.values) {
      result[category] = [];
    }
    
    // Raggruppa le postazioni per tipo locker usando perTipologia
    // Per ogni tipo locker, crea zone basate sulle postazioni
    for (var tipologia in perTipologia) {
      final tipologiaStr = tipologia['tipologia'] as String? ?? 'personali';
      
      LockerType category;
      switch (tipologiaStr) {
        case 'sportivi':
          category = LockerType.sportivi;
          break;
        case 'personali':
          category = LockerType.personali;
          break;
        case 'petFriendly':
          category = LockerType.petFriendly;
          break;
        case 'commerciali':
          category = LockerType.commerciali;
          break;
        case 'cicloturistici':
          category = LockerType.cicloturistici;
          break;
        default:
          category = LockerType.personali;
      }
      
      // Per ora, aggiungi tutte le postazioni a tutte le categorie
      // In futuro si può migliorare filtrando per tipo locker specifico
      for (var item in perPostazione) {
        final postazioneId = item['postazione'] as String? ?? '';
        final nome = item['nome'] as String? ?? postazioneId;
        final count = item['count'] as int? ?? 0;
        
        final zone = ZoneUsage(
          zoneId: postazioneId,
          zoneName: nome,
          totalUsage: count,
        );
        
        result[category]!.add(zone);
      }
    }
    
    // Se non ci sono tipologie, aggiungi tutte le postazioni a personali
    if (perTipologia.isEmpty) {
      for (var item in perPostazione) {
        final postazioneId = item['postazione'] as String? ?? '';
        final nome = item['nome'] as String? ?? postazioneId;
        final count = item['count'] as int? ?? 0;
        
        final zone = ZoneUsage(
          zoneId: postazioneId,
          zoneName: nome,
          totalUsage: count,
        );
        
        result[LockerType.personali]!.add(zone);
      }
    }
    
    return result;
  }

  // Mappa fascia oraria a TimeSlotCategoryData
  List<TimeSlotCategoryData> _mapFasciaOrariaToTimeSlotCategory(
    List<dynamic> perFasciaOraria,
    List<dynamic> perTipologia,
  ) {
    // Per ora, crea dati semplificati
    // In futuro si può migliorare usando i dati reali per categoria
    return [
      TimeSlotCategoryData(
        timeSlot: '00:00-06:00',
        categoryCounts: _getCategoryCountsForFascia('00-06', perFasciaOraria, perTipologia),
      ),
      TimeSlotCategoryData(
        timeSlot: '06:00-12:00',
        categoryCounts: _getCategoryCountsForFascia('06-12', perFasciaOraria, perTipologia),
      ),
      TimeSlotCategoryData(
        timeSlot: '12:00-18:00',
        categoryCounts: _getCategoryCountsForFascia('12-18', perFasciaOraria, perTipologia),
      ),
      TimeSlotCategoryData(
        timeSlot: '18:00-24:00',
        categoryCounts: _getCategoryCountsForFascia('18-24', perFasciaOraria, perTipologia),
      ),
    ];
  }

  Map<LockerType, int> _getCategoryCountsForFascia(
    String fascia,
    List<dynamic> perFasciaOraria,
    List<dynamic> perTipologia,
  ) {
    // Trova il count totale per questa fascia
    final fasciaData = perFasciaOraria.firstWhere(
      (f) => f['fascia'] == fascia,
      orElse: () => {'count': 0},
    );
    final totalCount = fasciaData['count'] as int? ?? 0;
    
    // Distribuisci proporzionalmente tra le categorie
    final totalTipologia = perTipologia.fold<int>(0, (sum, t) => sum + (t['count'] as int? ?? 0));
    
    final result = <LockerType, int>{};
    for (var tipologia in perTipologia) {
      final tipologiaStr = tipologia['tipologia'] as String? ?? 'personali';
      final tipologiaCount = tipologia['count'] as int? ?? 0;
      
      LockerType category;
      switch (tipologiaStr) {
        case 'sportivi':
          category = LockerType.sportivi;
          break;
        case 'personali':
          category = LockerType.personali;
          break;
        case 'petFriendly':
          category = LockerType.petFriendly;
          break;
        case 'commerciali':
          category = LockerType.commerciali;
          break;
        case 'cicloturistici':
          category = LockerType.cicloturistici;
          break;
        default:
          category = LockerType.personali;
      }
      
      if (totalTipologia > 0) {
        result[category] = ((tipologiaCount / totalTipologia) * totalCount).round();
      } else {
        result[category] = 0;
      }
    }
    
    return result;
  }

  // Mappa parchi popolari a LockerUsage
  Map<String, List<LockerUsage>> _mapParksToLockerUsage(List<dynamic> parksData) {
    final result = <String, List<LockerUsage>>{};
    
    for (var park in parksData) {
      final lockerId = park['lockerId'] as String? ?? '';
      final nome = park['nome'] as String? ?? lockerId;
      final utilizzi = park['utilizzi'] as int? ?? 0;
      
      // Per ora, raggruppa tutti i locker in una zona generica
      // In futuro si può migliorare usando zone reali
      const zoneId = 'all';
      if (!result.containsKey(zoneId)) {
        result[zoneId] = [];
      }
      
      result[zoneId]!.add(LockerUsage(
        lockerId: lockerId,
        lockerName: nome,
        lockerCode: lockerId,
        totalUsage: utilizzi,
      ));
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.isDarkMode;
    
    return CupertinoPageScaffold(
      backgroundColor: isDark 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        middle: Text(
          'Analytics',
          style: TextStyle(
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
          ),
        ),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
          color: CupertinoColors.black,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Filtri
            _buildFilters(isDark),
            
            // Contenuto principale
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CupertinoActivityIndicator(radius: 16),
                          const SizedBox(height: 16),
                          Text(
                            'Caricamento dati...',
                            style: TextStyle(
                              color: isDark ? CupertinoColors.white : CupertinoColors.black,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.exclamationmark_triangle,
                                size: 48,
                                color: CupertinoColors.systemRed,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              CupertinoButton(
                                onPressed: _loadAnalyticsData,
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: _buildContent(isDark),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 12),
          // Filtro periodo
          Row(
            children: [
              Text(
                'Periodo:',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoSegmentedControl<String>(
                  children: const {
                    'giorno': Text('Giorno'),
                    'settimana': Text('Settimana'),
                    'mese': Text('Mese'),
                    'anno': Text('Anno'),
                  },
                  groupValue: _selectedPeriod,
                  onValueChanged: (value) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                    _loadAnalyticsData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pulsante per tornare alla vista principale o alla classifica parchi
          if (_currentView != 'hourly')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    if (_currentView == 'lockerRanking') {
                      _currentView = 'zoneRanking';
                      _selectedPark = null;
                    } else {
                      _currentView = 'hourly';
                      _selectedCategory = null;
                      _selectedTimeSlot = null;
                      _selectedPark = null;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_left,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentView == 'lockerRanking' 
                            ? 'Torna alla classifica zone'
                            : 'Torna al grafico principale',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Filtro categoria
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LockerType.values.map((category) {
              final isSelected = _selectedCategory == category;
              return CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCategory = null;
                      _currentView = 'hourly';
                    } else {
                      _selectedCategory = category;
                      _currentView = 'zoneRanking';
                    }
                    _selectedTimeSlot = null;
                    _selectedPark = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.2)
                        : (isDark 
                            ? CupertinoColors.darkBackgroundGray 
                            : CupertinoColors.white),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : CupertinoColors.separator,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        category.icon,
                        size: 16,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? CupertinoColors.white : CupertinoColors.black),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category.label,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? CupertinoColors.white : CupertinoColors.black),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          // Filtro fascia oraria
          if (_currentView == 'hourly' || _currentView == 'timeSlot') ...[
            const SizedBox(height: 12),
            Text(
              'Fascia oraria:',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_timeSlotData.isEmpty ? mockTimeSlotCategoryData : _timeSlotData).map((timeSlot) {
                final isSelected = _selectedTimeSlot == timeSlot.timeSlot;
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTimeSlot = null;
                        _currentView = 'hourly';
                      } else {
                        _selectedTimeSlot = timeSlot.timeSlot;
                        _currentView = 'timeSlot';
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.2)
                          : (isDark 
                              ? CupertinoColors.darkBackgroundGray 
                              : CupertinoColors.white),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : CupertinoColors.separator,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      timeSlot.timeSlot,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? CupertinoColors.white : CupertinoColors.black),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_currentView) {
      case 'hourly':
        return _buildHourlyChart(isDark);
      case 'category':
        return _buildCategoryChart(isDark);
      case 'timeSlot':
        return _buildTimeSlotChart(isDark);
      case 'zoneRanking':
        return _buildZoneRanking(isDark);
      case 'lockerRanking':
        return _buildLockerRanking(isDark);
      default:
        return _buildHourlyChart(isDark);
    }
  }

  Widget _buildHourlyChart(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Affluenze per ora',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              // Usa MediaQuery per ottenere l'altezza dello schermo disponibile
              final screenHeight = MediaQuery.of(context).size.height;
              final chartHeight = (screenHeight * 0.35).clamp(250.0, 600.0);
              return SizedBox(
                height: chartHeight,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 130,
                    barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark 
                        ? CupertinoColors.darkBackgroundGray 
                        : CupertinoColors.white,
                    tooltipRoundedRadius: 8,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() % 3 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${value.toInt()}h',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark 
                                    ? CupertinoColors.white 
                                    : CupertinoColors.black,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark 
                                ? CupertinoColors.white 
                                : CupertinoColors.black,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: CupertinoColors.separator.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
                barGroups: (_hourlyData.isEmpty ? mockHourlyAffluence : _hourlyData).map((data) {
                  return BarChartGroupData(
                    x: data.hour,
                    barRods: [
                      BarChartRodData(
                        toY: data.count.toDouble(),
                        color: AppColors.primary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(bool isDark) {
    if (_selectedCategory == null) return const SizedBox();
    
    final categoryData = (_categoryData.isEmpty ? mockCategoryAffluence : _categoryData).firstWhere(
      (c) => c.category == _selectedCategory,
      orElse: () => CategoryAffluence(category: _selectedCategory!, count: 0),
    );
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selectedCategory!.icon,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Affluenze - ${_selectedCategory!.label}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  '${categoryData.count}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'utilizzi totali',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark 
                        ? CupertinoColors.white 
                        : CupertinoColors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotChart(bool isDark) {
    if (_selectedTimeSlot == null) return const SizedBox();
    
    final timeSlotData = (_timeSlotData.isEmpty ? mockTimeSlotCategoryData : _timeSlotData).firstWhere(
      (t) => t.timeSlot == _selectedTimeSlot,
      orElse: () => TimeSlotCategoryData(
        timeSlot: _selectedTimeSlot!,
        categoryCounts: {},
      ),
    );
    
    // Calcola maxCount gestendo il caso in cui categoryCounts è vuoto
    final maxCount = timeSlotData.categoryCounts.values.isEmpty
        ? 10.0 // Default se non ci sono dati
        : timeSlotData.categoryCounts.values.reduce((a, b) => a > b ? a : b);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiche per categoria - $_selectedTimeSlot',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              // Usa MediaQuery per ottenere l'altezza dello schermo disponibile
              final screenHeight = MediaQuery.of(context).size.height;
              final chartHeight = (screenHeight * 0.35).clamp(250.0, 600.0);
              return SizedBox(
                height: chartHeight,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (maxCount * 1.2).ceilToDouble(),
                    barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark 
                        ? CupertinoColors.darkBackgroundGray 
                        : CupertinoColors.white,
                    tooltipRoundedRadius: 8,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < LockerType.values.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              LockerType.values[index].label.substring(0, 3),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark 
                                    ? CupertinoColors.white 
                                    : CupertinoColors.black,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark 
                                ? CupertinoColors.white 
                                : CupertinoColors.black,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: CupertinoColors.separator.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
                barGroups: LockerType.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  final count = timeSlotData.categoryCounts[category] ?? 0;
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: AppColors.primary,
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildZoneRanking(bool isDark) {
    if (_selectedCategory == null) return const SizedBox();
    
    final zones = (_zoneUsageByCategory.isEmpty ? mockZoneUsageByCategory : _zoneUsageByCategory)[_selectedCategory] ?? [];
    final sortedZones = List<ZoneUsage>.from(zones)
      ..sort((a, b) => b.totalUsage.compareTo(a.totalUsage));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selectedCategory!.icon,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Classifica Zone - ${_selectedCategory!.label}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          sortedZones.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chart_bar,
                          size: 48,
                          color: CupertinoColors.systemGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nessuna zona disponibile per questa categoria',
                          style: TextStyle(
                            fontSize: 16,
                            color: CupertinoColors.systemGrey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ...sortedZones.asMap().entries.map((entry) {
            final index = entry.key;
            final zone = entry.value;
            final isSelected = _selectedPark == zone.zoneId;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _selectedPark = zone.zoneId;
                    _currentView = 'lockerRanking';
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : (isDark 
                            ? CupertinoColors.black 
                            : CupertinoColors.systemGrey6),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : CupertinoColors.separator,
                      width: isSelected ? 2 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone.zoneName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark 
                                    ? CupertinoColors.white 
                                    : CupertinoColors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${zone.totalUsage} utilizzi',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        color: isDark 
                            ? CupertinoColors.white 
                            : CupertinoColors.black,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLockerRanking(bool isDark) {
    if (_selectedPark == null || _selectedCategory == null) return const SizedBox();
    
    final lockers = (_lockerUsageByZone.isEmpty ? mockLockerUsageByZone : _lockerUsageByZone)[_selectedPark] ?? [];
    final sortedLockers = List<LockerUsage>.from(lockers)
      ..sort((a, b) => b.totalUsage.compareTo(a.totalUsage));
    
    final zones = mockZoneUsageByCategory[_selectedCategory] ?? [];
    final selectedZone = zones.firstWhere(
      (z) => z.zoneId == _selectedPark,
      orElse: () => zones.isNotEmpty ? zones.first : const ZoneUsage(zoneId: '', zoneName: '', totalUsage: 0),
    );
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () {
                  setState(() {
                    _currentView = 'zoneRanking';
                    _selectedPark = null;
                  });
                },
                child: Icon(
                  CupertinoIcons.arrow_left,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Classifica Locker - ${selectedZone.zoneName}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...sortedLockers.asMap().entries.map((entry) {
            final index = entry.key;
            final locker = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? CupertinoColors.black 
                      : CupertinoColors.systemGrey6,
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locker.lockerName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${locker.lockerCode} - ${locker.totalUsage} utilizzi',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

