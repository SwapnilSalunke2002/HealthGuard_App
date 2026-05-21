import 'dart:async';
import 'dart:math' as math; 
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Project Imports
import '../../widgets/components.dart';
import '../../services/health_retrieval_service.dart';
import '../../services/health_registry.dart';
import '../../services/shared_prefs_service.dart'; 
import '../../models/health_metric_def.dart';
import '../../models/health_point.dart';

// ID Imports
import '../../data/health_ids.dart';
import '../../data/env_ids.dart';
import '../../data/subjective_ids.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final HealthRetrievalService _retrievalService = HealthRetrievalService();
  final SharedPrefsService _prefs = SharedPrefsService();
  final ScrollController _scrollController = ScrollController(); 

  final List<String> _pinnedMetrics = [
    HealthID.heartRate,
    HealthID.steps,
    HealthID.bodyTemp,
    EnvID.noiseLevel,
  ];

  List<String> _dynamicTwinMetrics = [];

  final Map<String, List<String>> _metricCategories = {
    "VITALS": [HealthID.heartRate, HealthID.bloodPressure, HealthID.spo2, HealthID.respRate, HealthID.bodyTemp],
    "ACTIVITY & BODY": [HealthID.steps, HealthID.distance, HealthID.calories, HealthID.water, HealthID.sleep, HealthID.weight, HealthID.height],
    "ENVIRONMENT": [EnvID.ambientTemp, EnvID.humidity, EnvID.airQuality, EnvID.noiseLevel, EnvID.pressure, EnvID.altitude],
    "SUBJECTIVE": [SubjectiveID.mood, SubjectiveID.energy, SubjectiveID.stress, SubjectiveID.focus, SubjectiveID.pain],
    "LABS: METABOLISM": [HealthID.glucose, HealthID.hba1c],
    "LABS: HEART (LIPIDS)": [HealthID.cholesterol, HealthID.hdl, HealthID.ldl, HealthID.triglycerides],
    "LABS: BLOOD COUNT": [HealthID.hemoglobin, HealthID.platelets, HealthID.wbc, HealthID.rbc, HealthID.neutrophils, HealthID.lymphocytes, HealthID.monocytes, HealthID.eosinophils, HealthID.basophils],
    "LABS: ORGANS": [HealthID.creatinine, HealthID.urea, HealthID.uricAcid, HealthID.sgot, HealthID.sgpt, HealthID.bilirubin],
    "LABS: THYROID": [HealthID.tsh, HealthID.t3, HealthID.t4],
  };

  final List<Color> _distinctPalette = [
    const Color(0xFF00E5FF), const Color(0xFFFF4081), const Color(0xFF76FF03), 
    const Color(0xFFFFAB40), const Color(0xFFE040FB), const Color(0xFF2979FF),
  ];

  final List<String> _timeLabels = ["1D", "1W", "1M", "3M", "ALL"];

  String _selectedMetricId = HealthID.systemHealthScore; 
  int _timeRangeIndex = 0; 
  bool _isLoadingChart = true;
  
  List<HealthPoint> _historyData = [];
  List<HealthPoint> _twinErrorData = []; 
  
  final Map<String, dynamic> _liveValues = {}; 
  StreamSubscription? _dailySummarySub;
  Timer? _silentMetricPoller;

  @override
  void initState() {
    super.initState();
    
    List<String> savedFeatures = _prefs.getList('active_twin_features');
    if (savedFeatures.isEmpty) {
      _dynamicTwinMetrics = [
        HealthID.heartRate, HealthID.spo2, HealthID.bodyTemp, HealthID.respRate
      ];
    } else {
      _dynamicTwinMetrics = savedFeatures;
    }
    
    _setupRealtimeListener(); 
    _fetchChartData();  
    _pollSilentMetrics();
    _silentMetricPoller = Timer.periodic(const Duration(seconds: 2), (_) => _pollSilentMetrics());
  }

  @override
  void dispose() {
    _dailySummarySub?.cancel();
    _silentMetricPoller?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupRealtimeListener() {
    _dailySummarySub = _retrievalService.streamTodaySummary().listen((metrics) {
      if (mounted) setState(() => _liveValues.addAll(metrics));
    });
  }

  void _pollSilentMetrics() {
    int steps = _prefs.getInt(HealthID.steps);
    var noiseMap = _prefs.getMap(EnvID.noiseLevel);
    double noise = noiseMap.isNotEmpty ? (noiseMap['val'] as num).toDouble() : 0.0;

    if (mounted) {
      setState(() {
        _liveValues[HealthID.steps] = steps;
        _liveValues[EnvID.noiseLevel] = noise.round();
      });
    }
  }

  void _onMetricSelected(String id) {
    if (_selectedMetricId == id) return;
    setState(() { _selectedMetricId = id; _isLoadingChart = true; });

    if (id != HealthID.systemHealthScore && !_pinnedMetrics.contains(id)) {
      setState(() => _pinnedMetrics.add(id));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.easeOutQuart);
        }
      });
    }
    _fetchChartData();
  }

  DateTime _getStartDate(DateTime now) {
    switch (_timeRangeIndex) {
      case 0: return now.subtract(const Duration(days: 1));
      case 1: return now.subtract(const Duration(days: 7));
      case 2: return now.subtract(const Duration(days: 30));
      case 3: return now.subtract(const Duration(days: 90));
      default: return DateTime(2023); 
    }
  }

  Future<void> _fetchChartData() async {
    if (mounted) setState(() => _isLoadingChart = true);
    DateTime now = DateTime.now();
    DateTime start = _getStartDate(now);

    try {
      final rawData = await _retrievalService.fetchHistory(metricId: _selectedMetricId, start: start, end: now);
      
      List<HealthPoint> rawTwinError = [];
      if (_selectedMetricId != HealthID.systemHealthScore && _dynamicTwinMetrics.contains(_selectedMetricId)) {
        try {
           rawTwinError = await _retrievalService.fetchHistory(metricId: "${_selectedMetricId}_mse", start: start, end: now);
        } catch (_) { }
      }

      if (mounted) {
        setState(() {
          _historyData = _aggregateData(rawData, _timeRangeIndex);
          _historyData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          _twinErrorData = _aggregateData(rawTwinError, _timeRangeIndex);
          _twinErrorData.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          _isLoadingChart = false;
        });
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
      if (mounted) setState(() => _isLoadingChart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOverview = _selectedMetricId == HealthID.systemHealthScore;
    HealthMetricDef? singleDef = HealthRegistry.get(_selectedMetricId);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          const GlobalAnimatedBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Expanded(child: Text("ANALYTICS", style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                        _buildTimeSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 54, 
                    child: ListView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24), 
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildOverviewTile(isSelected: isOverview),
                        Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 12), color: Colors.white.withOpacity(0.1)),
                        
                        ..._pinnedMetrics.map((id) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _buildMetricTile(id, isSelected: _selectedMetricId == id, onTap: () => _onMetricSelected(id)),
                        )),

                        GestureDetector(
                          onTap: () => _showMetricSelectionSheet(isLayerMode: false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05), 
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ), 
                            child: const Icon(Icons.add, color: AppColors.textGrey, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: singleDef != null || isOverview 
                        ? _buildSingleMetricContent(singleDef, isOverview: isOverview) 
                        : const SizedBox(),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOverviewTile({required bool isSelected}) {
    return GestureDetector(
      onTap: () => _onMetricSelected(HealthID.systemHealthScore),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.5) : Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.health_and_safety_rounded, size: 16, color: isSelected ? const Color(0xFF00E5FF) : AppColors.textGrey),
            const SizedBox(width: 8),
            Text("Health Index", style: TextStyle(color: isSelected ? Colors.white : AppColors.textGrey, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleMetricContent(HealthMetricDef? metricDef, {bool isOverview = false}) {
    if (_isLoadingChart) {
      return const SizedBox(
        height: 400, 
        child: Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 3))
      );
    }

    String currentId = isOverview ? HealthID.systemHealthScore : (metricDef?.id ?? "");
    Color primaryColor = isOverview ? const Color(0xFF00E5FF) : (metricDef?.color ?? Colors.white);
    String unit = isOverview ? "/100" : (metricDef?.unit ?? "");
    
    bool isTwinSupported = _dynamicTwinMetrics.contains(currentId);

    List<FlSpot> spots = _getSpots(currentId);
    bool hasData = spots.isNotEmpty;
    if (!hasData) spots = [const FlSpot(0, 0), const FlSpot(6, 0)];

    bool hasRecentStress = false;
    if (isTwinSupported && _twinErrorData.isNotEmpty) {
      DateTime twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
      var recentErrors = _twinErrorData.where((e) => e.timestamp.isAfter(twentyFourHoursAgo));
      
      if (recentErrors.isNotEmpty) {
        double maxError = recentErrors.map((e) => e.y).fold(0.0, math.max);
        if (maxError > 0.15) hasRecentStress = true;
      }
    }

    return Column(
      children: [
        if (isOverview) 
          _buildOverviewInsightCard() 
        else if (metricDef != null) 
          isTwinSupported 
              ? _buildTwinInsightCard(metricDef, hasRecentStress: hasRecentStress)
              : _buildStandardInsightCard(metricDef),
        
        const SizedBox(height: 16),
        Row(children: [
          _buildStatCard("Avg", hasData ? _calculateAverage(spots) : "--", unit, primaryColor),
          const SizedBox(width: 10),
          _buildStatCard("Max", hasData ? _calculateMax(spots) : "--", unit, Colors.white),
          const SizedBox(width: 10),
          _buildStatCard("Min", hasData ? _calculateMin(spots) : "--", unit, Colors.white),
        ]),
        const SizedBox(height: 24),
        _buildSingleChart(primaryColor, unit, spots, hasData, isOverview: isOverview, isTwinSupported: isTwinSupported, hasRecentStress: hasRecentStress),
      ],
    );
  }

  Widget _buildSingleChart(Color primaryColor, String unit, List<FlSpot> actualSpots, bool hasData, {bool isOverview = false, bool isTwinSupported = false, bool hasRecentStress = false}) {
    List<LineChartBarData> lines = [];
    
    lines.add(LineChartBarData(
      spots: actualSpots, 
      isCurved: true, 
      color: hasData ? primaryColor : Colors.transparent, 
      barWidth: isOverview ? 4.0 : 3.0, 
      dotData: const FlDotData(show: false), 
      belowBarData: BarAreaData(
        show: isOverview && hasData,
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.4), primaryColor.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    ));

    if (!isOverview && isTwinSupported && hasData && actualSpots.length > 2) {
      List<FlSpot> predictedSpots = [];
      for (int i = 0; i < actualSpots.length; i++) {
        double sum = 0;
        int count = 0;
        int window = 4;
        for (int j = math.max(0, i - window); j <= i; j++) {
          sum += actualSpots[j].y;
          count++;
        }
        predictedSpots.add(FlSpot(actualSpots[i].x, sum / count));
      }

      lines.add(LineChartBarData(
        spots: predictedSpots, 
        isCurved: true, 
        color: Colors.white.withOpacity(0.4), 
        barWidth: 2, 
        dashArray: [5, 5], 
        dotData: const FlDotData(show: false), 
      ));
    }

    // 🚀 UI FIX: The Color Clash Fix. If the metric is Red, shade the anomaly in Hazard Orange!
    Color anomalyFill = (primaryColor == AppColors.signalRed)
        ? const Color(0xFFFF9100).withOpacity(0.35) 
        : AppColors.signalRed.withOpacity(0.25);

    return _buildChartContainer(
      lines, 
      unit: unit,
      showAnomalyShading: !isOverview && isTwinSupported && hasRecentStress, 
      anomalyFillColor: anomalyFill,
      forceYMax: isOverview ? 100 : null, 
    );
  }

  Widget _buildChartContainer(
      List<LineChartBarData> lines, {
      String? unit, 
      double? minY, 
      double? maxY, 
      double? forceYMax, 
      bool showAnomalyShading = false,
      required Color anomalyFillColor, // Passed down from the fix above
    }) {
      
    DateTime now = DateTime.now();
    DateTime start = _getStartDate(now);
    
    // 🚀 UI FIX: Auto-Scale the X-Axis so sparse data expands nicely
    double dataMinX = double.infinity;
    double dataMaxX = double.negativeInfinity;
    
    for (var line in lines) {
      for (var spot in line.spots) {
        if (spot.x < dataMinX) dataMinX = spot.x;
        if (spot.x > dataMaxX) dataMaxX = spot.x;
      }
    }

    double minX;
    double maxX;

    if (dataMinX == double.infinity || dataMinX == dataMaxX) {
      // Fallback if there is almost no data
      minX = start.millisecondsSinceEpoch.toDouble();
      maxX = now.millisecondsSinceEpoch.toDouble();
    } else {
      // Add 5% padding to the visual edges
      double padding = (dataMaxX - dataMinX) * 0.05;
      minX = dataMinX - padding;
      maxX = dataMaxX + padding;
    }

    double xInterval = (maxX - minX) / 4;
    if (xInterval <= 0) xInterval = 1;

    // Y-Axis dynamic scaling
    if (minY == null || maxY == null) {
      double allMin = double.infinity;
      double allMax = double.negativeInfinity;
      for (var line in lines) {
        for (var spot in line.spots) {
          if (spot.y < allMin) allMin = spot.y;
          if (spot.y > allMax) allMax = spot.y;
        }
      }
      if (allMin == double.infinity) { allMin = 0; allMax = 100; } 
      else if (allMin == allMax) { allMin -= 10; allMax += 10; }
      
      double range = allMax - allMin;
      minY = allMin - (range * 0.10); 
      maxY = forceYMax ?? (allMax + (range * 0.20)); 
      if (minY < 0) minY = 0; 
    }

    double yInterval = ((maxY! - minY!) / 4).abs();
    if (yInterval == 0) yInterval = 1;

    String formatYLabel(double value) {
      if (value >= 1000) return "${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k";
      return value.toInt().toString();
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(8, 24, 24, 12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: LineChart(
        LineChartData(
          minX: minX, maxX: maxX, minY: minY, maxY: maxY,
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: yInterval, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, interval: yInterval, getTitlesWidget: (v, m) { if (v <= minY! || v >= maxY!) return const SizedBox(); return Padding(padding: const EdgeInsets.only(right: 8.0), child: Text(formatYLabel(v), textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.bold))); })),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: xInterval, getTitlesWidget: (value, meta) { if (value >= maxX - (xInterval * 0.2)) return const SizedBox(); final date = DateTime.fromMillisecondsSinceEpoch(value.toInt()); final text = Text(_formatDateForAxis(date), style: const TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.bold)); if ((value - minX).abs() < xInterval * 0.1) return SideTitleWidget(meta: meta, space: 6, fitInside: SideTitleFitInsideData.fromTitleMeta(meta), child: text); return Padding(padding: const EdgeInsets.only(top: 8.0), child: text); })),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => const Color(0xFF1E1E1E).withOpacity(0.95), fitInsideHorizontally: true, fitInsideVertically: true, getTooltipItems: (touchedSpots) => touchedSpots.map((spot) { bool isActual = spot.barIndex == 0; String prefix = isActual ? "" : "Baseline: "; return LineTooltipItem("$prefix${spot.y.toInt()} $unit", TextStyle(color: spot.bar.color, fontWeight: FontWeight.bold, fontSize: 12)); }).toList())),
          lineBarsData: lines.map((line) => line.copyWith(dotData: FlDotData(show: line.spots.length < 15), barWidth: line.spots.length > 50 ? 1.5 : line.barWidth)).toList(),
          betweenBarsData: showAnomalyShading && lines.length >= 2 ? [BetweenBarsData(fromIndex: 0, toIndex: 1, color: anomalyFillColor)] : [], 
        ),
      ),
    );
  }

  Widget _buildOverviewInsightCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(color: const Color(0xFF00E5FF).withOpacity(0.08), border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)), borderRadius: BorderRadius.circular(16)), 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF00E5FF).withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF00E5FF), size: 24)),
          const SizedBox(width: 16), 
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Your Body's Engine Light", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)), 
            const SizedBox(height: 6), 
            Text("This score stays near 100 when your vitals match your normal, healthy habits. If it drops, your body is fighting off unexpected stress, fatigue, or illness.", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.5))
          ]))
        ]
      )
    );
  }

  Widget _buildTwinInsightCard(HealthMetricDef metric, {required bool hasRecentStress}) {
    if (_historyData.isEmpty) return const SizedBox();
    Color cardAccent = hasRecentStress ? AppColors.signalRed : metric.color;
    IconData cardIcon = hasRecentStress ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded;
    String title = hasRecentStress ? "RECENT STRESS DETECTED" : "VITALS IN SYNC (LAST 24H)";
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: cardAccent.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(cardIcon, color: cardAccent, size: 18), const SizedBox(width: 8), Text(title, style: TextStyle(color: cardAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0))]),
        const SizedBox(height: 10),
        RichText(text: TextSpan(style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.5), children: [
          const TextSpan(text: "The "), TextSpan(text: "dashed line ", style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold)), const TextSpan(text: "is what your AI Digital Twin expected based on your history. "),
          if (hasRecentStress) TextSpan(text: "The colored shading indicates your body has been working unusually hard in the last 24 hours.", style: TextStyle(color: AppColors.signalRed, fontWeight: FontWeight.bold))
          else TextSpan(text: "Over the last 24 hours, your actual vitals have aligned perfectly with expectations.", style: TextStyle(color: metric.color, fontWeight: FontWeight.bold))
        ])),
      ]),
    );
  }

  Widget _buildStandardInsightCard(HealthMetricDef metric) {
    if (_historyData.isEmpty) return const SizedBox();
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: metric.color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: metric.color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.query_stats_rounded, color: metric.color, size: 18), const SizedBox(width: 8), Text("STANDARD TELEMETRY", style: TextStyle(color: metric.color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0))]),
        const SizedBox(height: 10),
        RichText(text: TextSpan(style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.5), children: [
          TextSpan(text: "Displaying raw tracking data for ${metric.label.toLowerCase()}. "),
          const TextSpan(text: "This metric is tracked independently and is not currently utilized by the core Digital Twin anomaly model.", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
        ])),
      ]),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color valueColor) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: AppColors.textGrey.withOpacity(0.7), fontSize: 10)), const SizedBox(height: 6), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold, height: 1.0)), const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(bottom: 2.0), child: Text(unit, style: const TextStyle(color: AppColors.textGrey, fontSize: 10)))]))])));
  }

  List<FlSpot> _getSpots(String metricId) {
    if (_historyData.isEmpty) return [];
    List<FlSpot> spots = [];
    for (var dataPoint in _historyData) { spots.add(FlSpot(dataPoint.timestamp.millisecondsSinceEpoch.toDouble(), dataPoint.y)); }
    return spots;
  }

  List<HealthPoint> _aggregateData(List<HealthPoint> rawData, int timeIndex) {
    if (timeIndex == 0 || rawData.isEmpty) return rawData; 
    Map<String, List<double>> groupedValues = {};
    Map<String, DateTime> groupedTimes = {};
    for (var point in rawData) {
      double yVal = point.y; DateTime local = point.timestamp.toLocal();
      String key = "${local.year}-${local.month}-${local.day}";
      groupedValues.putIfAbsent(key, () => []).add(yVal);
      groupedTimes.putIfAbsent(key, () => DateTime(local.year, local.month, local.day, 12)); 
    }
    List<HealthPoint> aggregated = [];
    groupedValues.forEach((key, values) {
      double avg = values.fold(0.0, (a, b) => a + b) / values.length;
      aggregated.add(HealthPoint(id: rawData.first.id, value: avg, timestamp: groupedTimes[key]!));
    });
    return aggregated;
  }

  String _formatDateForAxis(DateTime date) {
    if (_timeRangeIndex == 0) return DateFormat('h a').format(date); 
    if (_timeRangeIndex == 1) return DateFormat('E').format(date); 
    if (_timeRangeIndex == 2) return DateFormat('d/M').format(date); 
    return DateFormat('MMM').format(date); 
  }

  String _calculateAverage(List<FlSpot> spots) { if (_historyData.isEmpty) return "--"; double sum = spots.fold(0, (prev, spot) => prev + spot.y); return (sum / spots.length).toStringAsFixed(1); }
  String _calculateMax(List<FlSpot> spots) { if (_historyData.isEmpty) return "--"; return spots.isEmpty ? "--" : spots.map((e) => e.y).reduce(math.max).toStringAsFixed(0); }
  String _calculateMin(List<FlSpot> spots) { if (_historyData.isEmpty) return "--"; return spots.isEmpty ? "--" : spots.map((e) => e.y).reduce(math.min).toStringAsFixed(0); }

  void _showMetricSelectionSheet({required bool isLayerMode}) {
    String searchQuery = "";
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF121212), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (context) {
      return DraggableScrollableSheet(initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false, builder: (_, controller) {
        return StatefulBuilder(builder: (context, setStateSheet) {
          return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))), 
            const SizedBox(height: 20), 
            const Text("Select Single Metric", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 16), 
            TextField(onChanged: (val) => setStateSheet(() => searchQuery = val.toLowerCase()), style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: "Search metrics...", hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0))),
            const SizedBox(height: 16),
            Expanded(child: Scrollbar(controller: controller, thumbVisibility: true, child: ListView(controller: controller, children: [
              if (searchQuery.isNotEmpty) 
                Wrap(spacing: 12, runSpacing: 12, children: _getFilteredMetrics(searchQuery).map((id) => _buildWrapItem(id, false)).toList())
              else 
                ..._metricCategories.entries.map((entry) {
                  final validMetrics = entry.value.where((id) => HealthRegistry.get(id) != null).toList();
                  if (validMetrics.isEmpty) return const SizedBox();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(entry.key, style: const TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                    Wrap(spacing: 12, runSpacing: 12, children: validMetrics.map((id) => _buildWrapItem(id, false)).toList()),
                    const SizedBox(height: 16),
                  ]);
                }).toList(),
            ])))
          ]));
        });
      });
    });
  }

  List<String> _getFilteredMetrics(String query) {
    List<String> matches = [];
    _metricCategories.forEach((_, list) {
      for (var id in list) { final def = HealthRegistry.get(id); if (def != null && def.label.toLowerCase().contains(query)) matches.add(id); }
    });
    return matches;
  }

  Widget _buildWrapItem(String id, bool isLayerMode) {
    return SizedBox(width: (MediaQuery.of(context).size.width - 48 - 12) / 2, child: _buildMetricTile(id, isSelected: _selectedMetricId == id, onTap: () { Navigator.pop(context); _onMetricSelected(id); }));
  }

  Widget _buildMetricTile(String metricId, {bool isSelected = false, VoidCallback? onTap}) {
    final def = HealthRegistry.get(metricId);
    if (def == null) return const SizedBox();
    final rawVal = _liveValues[metricId];
    String displayVal = "--";
    if (rawVal != null) displayVal = (metricId == HealthID.steps) ? NumberFormat('#,###').format(rawVal) : "$rawVal"; 
    return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isSelected ? def.color.withOpacity(0.15) : Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? def.color.withOpacity(0.5) : Colors.white.withOpacity(0.05), width: 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: def.color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(def.icon, size: 14, color: def.color)), const SizedBox(width: 10), Flexible(fit: FlexFit.loose, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(def.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? Colors.white : AppColors.textGrey, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 11)), Text("$displayVal ${def.unit}", maxLines: 1, style: TextStyle(color: isSelected ? def.color : AppColors.textGrey.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold))]))])));
  }

  Widget _buildTimeSelector() {
    return Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _timeLabels.asMap().entries.map((entry) { final isSelected = _timeRangeIndex == entry.key; return GestureDetector(onTap: () { if (_timeRangeIndex != entry.key) { setState(() => _timeRangeIndex = entry.key); _fetchChartData(); } }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Text(entry.value, style: TextStyle(color: isSelected ? Colors.white : AppColors.textGrey, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)))); }).toList())));
  }
}