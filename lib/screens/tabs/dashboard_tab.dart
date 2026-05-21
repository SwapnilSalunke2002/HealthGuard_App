import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// Project Imports
import '../../widgets/components.dart';
import '../../services/shared_prefs_service.dart';
import '../../services/health_retrieval_service.dart';
import '../../services/intelligence_service.dart'; 
import '../../data/health_ids.dart';
import '../../data/env_ids.dart';
import '../../widgets/cyber_snackbar.dart';

// Silent Services
import '../../services/silent_monitoring/silent_health_service.dart';
import '../../services/silent_monitoring/silent_env_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with WidgetsBindingObserver {
  // Services
  final HealthRetrievalService _healthService = HealthRetrievalService();
  final SharedPrefsService _prefs = SharedPrefsService();

  // --- UI STATE ---
  String _location = "Scanning..."; 
  
  // Passive Environment
  String _temp = "--";
  String _humidity = "--";
  String _aqiLabel = "--";
  Color _aqiColor = AppColors.textGrey;
  String _noiseLabel = "--";
  Color _noiseColor = AppColors.textGrey;

  // Passive Health
  String _steps = "--";

  // Active Vitals
  String _latestHR = "--";
  String _latestSpO2 = "--";

  // --- AI INTELLIGENCE STATE ---
  int _healthScore = 100; 
  String _aiDiagnosis = "System initializing...";
  int _alertLevel = 0;
  bool _isAnalyzing = false;

  // We keep the state to know if it's calibrating, but we don't render the UI here
  String _systemStatus = "UNKNOWN";

  Timer? _silentMetricPoller;
  StreamSubscription? _vitalsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    SilentHealthService().init();
    SilentEnvService().init();

    _initialSetup();
  }

  Future<void> _initialSetup() async {
    _loadLocationName();

    _vitalsSub = _healthService.streamTodaySummary().listen((data) {
      if (mounted) {
        setState(() {
          _latestHR = "${data[HealthID.heartRate] ?? '--'}";
          _latestSpO2 = "${data[HealthID.spo2] ?? '--'}";
        });
      }
    });

    _refreshSilentMetrics();
    _silentMetricPoller = Timer.periodic(const Duration(seconds: 2), (_) => _refreshSilentMetrics());

    await SilentEnvService().performBackgroundSync();
    if (mounted) _refreshSilentMetrics();
    
    _runAIAnalysis();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _silentMetricPoller?.cancel();
    _vitalsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLocationName();
      _refreshSilentMetrics();
      _runAIAnalysis(); 
    }
  }

  // --- THE AI ORCHESTRATOR ---
  Future<void> _runAIAnalysis() async {
    if (_isAnalyzing) return;
    
    setState(() {
      _isAnalyzing = true;
      _aiDiagnosis = "Analyzing vitals via Cloud AI...";
    });

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
      
      // 1. Parse All Vitals (Paper 2)
      double hr = double.tryParse(_latestHR) ?? 70.0; 
      double spo2 = double.tryParse(_latestSpO2) ?? 98.0;
      double bodyTemp = _prefs.getMap(HealthID.bodyTemp)['val']?.toDouble() ?? 37.0; 
      double respRate = _prefs.getMap(HealthID.respRate)['val']?.toDouble() ?? 16.0; 

      // 2. Parse Context/Environment (Paper 1)
      int steps = _prefs.getInt(HealthID.steps);
      double temp = _prefs.getMap(EnvID.ambientTemp)['val']?.toDouble() ?? 20.0;
      double rhum = _prefs.getMap(EnvID.humidity)['val']?.toDouble() ?? 50.0;
      int aqi = _prefs.getMap(EnvID.airQuality)['val']?.toInt() ?? 50;

      // 3. Ping the upgraded AI Engine
      AIAnalysisResult? result = await IntelligenceService.analyzeVitals(
        userId: userId,
        currentHeartRate: hr,
        currentSpO2: spo2,
        currentBodyTemp: bodyTemp,
        currentRespRate: respRate,
        contextSteps: steps,
        contextTemp: temp,
        contextRhum: rhum,
        contextAqi: aqi,
        weight: 70.0, 
      );

      if (mounted && result != null) {
        // 🚀 THE SCALABILITY BRIDGE: Save the exact features the AI just analyzed!
        // This tells the AnalyticsTab exactly which graphs should get the Digital Twin dashed line.
        _prefs.setList('active_twin_features', result.featureAnalysis.keys.toList());

        setState(() {
          _healthScore = result.healthScore;
          _aiDiagnosis = result.message;
          _alertLevel = result.alertLevel;
          _systemStatus = result.status;
        });
      } else if (mounted) {
        setState(() {
          _aiDiagnosis = "AI Engine Offline. Displaying raw telemetry.";
        });
      }
    } catch (e) {
      print("AI Pipeline Error: $e");
      if (mounted) setState(() => _aiDiagnosis = "Error connecting to AI.");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
      print("🚀${_aiDiagnosis}");
    }
  }

  Future<void> _loadLocationName() async {
    if (!mounted) return;
    bool hasPermission = await Permission.locationWhenInUse.isGranted;
    if (!hasPermission) {
      setState(() => _location = "Loc: Off");
      return;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (mounted && placemarks.isNotEmpty) {
        setState(() => _location = placemarks[0].locality ?? placemarks[0].subLocality ?? "Unknown Area");
      }
    } catch (e) {
      if (mounted) setState(() => _location = "GPS Error");
    }
  }

  void _refreshSilentMetrics() {
    int rawSteps = _prefs.getInt(HealthID.steps);
    String stepsStr = rawSteps > 0 ? NumberFormat('#,###').format(rawSteps) : "0";

    double getVal(String key) {
      var map = _prefs.getMap(key);
      if (map.isEmpty) return 0.0;
      return (map['val'] as num).toDouble();
    }

    double tempVal = getVal(EnvID.ambientTemp);
    double noiseVal = getVal(EnvID.noiseLevel);
    int humVal = getVal(EnvID.humidity).toInt();
    int aqiVal = getVal(EnvID.airQuality).toInt();

    Color qColor = AppColors.textGrey;
    if (aqiVal > 0) {
      if (aqiVal <= 50) qColor = AppColors.signalGreen;
      else if (aqiVal <= 100) qColor = AppColors.signalYellow;
      else qColor = AppColors.signalRed;
    }

    Color nColor = AppColors.textGrey;
    if (noiseVal > 70) nColor = Colors.orange;
    if (noiseVal > 85) nColor = AppColors.signalRed;
    else if (noiseVal > 0) nColor = AppColors.neonBlue;

    if (mounted) {
      setState(() {
        _steps = stepsStr;
        _temp = tempVal == 0 ? "--" : "${tempVal.toStringAsFixed(1)}°C";
        _humidity = humVal == 0 ? "--" : "$humVal%";
        _aqiLabel = aqiVal == 0 ? "--" : "$aqiVal";
        _aqiColor = qColor;
        _noiseLabel = noiseVal == 0 ? "Silent" : "${noiseVal.toStringAsFixed(0)} dB";
        _noiseColor = nColor;
      });
    }
  }

  // --- 🧪 THE THESIS DEMO SIMULATOR ---
  void _showDemoSimulatorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🧪 THESIS DEMO SIMULATOR", style: TextStyle(color: AppColors.neonBlue, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              const Text("Inject controlled telemetry states to test AI Pipeline edge cases.", style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
              const SizedBox(height: 24),
              
              // SCENARIO 1: Nominal Baseline
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppColors.signalGreen),
                title: const Text("1. Baseline Rest (Normal)", style: TextStyle(color: Colors.white)),
                subtitle: const Text("HR: 68 | SpO2: 99 | Steps: 200 | Temp: 22°C", style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                onTap: () {
                  setState(() { _latestHR = "68"; _latestSpO2 = "99"; });
                  _prefs.setInt(HealthID.steps, 200);
                  _prefs.setMap(EnvID.ambientTemp, {'val': 22.0});
                  Navigator.pop(context);
                  _runAIAnalysis();
                },
              ),
              
              // SCENARIO 2: Paper 1 (Context Engine Filters Noise)
              ListTile(
                leading: const Icon(Icons.directions_run, color: AppColors.signalYellow),
                title: const Text("2. Active Workout (Contextual Safe)", style: TextStyle(color: Colors.white)),
                subtitle: const Text("HR: 135 | SpO2: 98 | Steps: 8500 | Temp: 26°C", style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                onTap: () {
                  setState(() { _latestHR = "135"; _latestSpO2 = "98"; });
                  _prefs.setInt(HealthID.steps, 8500);
                  _prefs.setMap(EnvID.ambientTemp, {'val': 26.0});
                  Navigator.pop(context);
                  _runAIAnalysis(); // Context should mark this SAFE because of steps/heat
                },
              ),
              
              // SCENARIO 3: Paper 2 (Digital Twin Detects Clinical Anomaly)
              ListTile(
                leading: const Icon(Icons.warning, color: AppColors.signalRed),
                title: const Text("3. Clinical Anomaly (Unexplained Spike)", style: TextStyle(color: Colors.white)),
                subtitle: const Text("HR: 130 | SpO2: 94 | Steps: 0 | Temp: 22°C", style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                onTap: () {
                  setState(() { _latestHR = "130"; _latestSpO2 = "94"; });
                  _prefs.setInt(HealthID.steps, 0);
                  _prefs.setMap(EnvID.ambientTemp, {'val': 22.0});
                  Navigator.pop(context);
                  _runAIAnalysis(); // AI should panic: high HR + low SpO2 while sitting still
                },
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    Color diagnosisColor = AppColors.textGrey;
    if (_alertLevel == 1) diagnosisColor = AppColors.signalYellow;
    if (_alertLevel == 2) diagnosisColor = AppColors.signalRed;

    return RefreshIndicator(
      onRefresh: _runAIAnalysis,
      color: AppColors.neonBlue,
      backgroundColor: const Color(0xFF1E1E24),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), 
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // THE GAUGE REMAINS
            GestureDetector(
              onLongPress: () => _showDemoSimulatorSheet(), // 🚀 THE HIDDEN TRIGGER
              child: BeautySignalGauge(score: _healthScore.toDouble())),
            
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  key: ValueKey<String>(_aiDiagnosis),
                  children: [
                    if (_isAnalyzing) 
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: SizedBox(
                          width: 12, height: 12, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue)
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _aiDiagnosis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: diagnosisColor,
                          fontSize: 12,
                          fontWeight: _alertLevel > 0 ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- BIO-METRICS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("BIO-METRICS", style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  Icon(Icons.more_horiz, color: AppColors.textGrey, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              height: 120, 
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  MetricPill(label: "Heart Rate", value: _latestHR, unit: "bpm", icon: Icons.favorite_rounded, iconColor: AppColors.signalRed),
                  const SizedBox(width: 12),
                  MetricPill(label: "SpO2", value: _latestSpO2, unit: "%", icon: Icons.water_drop_rounded, iconColor: AppColors.neonBlue),
                  const SizedBox(width: 12),
                  MetricPill(label: "Steps", value: _steps, unit: "", icon: Icons.directions_walk_rounded, iconColor: const Color(0xFFFF9100)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- ENVIRONMENT ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("ENVIRONMENT", style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  
                  GestureDetector(
                    onTap: () async {
                      var locStatus = await Permission.locationWhenInUse.request();
                      if (locStatus.isGranted) {
                        setState(() => _location = "Updating...");
                        await _loadLocationName(); 
                        await SilentEnvService().performBackgroundSync();
                        _runAIAnalysis(); 
                        CyberSnackbar.show(context, "Environment Scanned", type: SnackbarType.success);
                      } else if(mounted) {
                        CyberSnackbar.show(context, "Location required", type: SnackbarType.warning);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.neonBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neonBlue.withOpacity(0.15))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.neonBlue, size: 10),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 90), 
                            child: Text(_location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.refresh_rounded, color: AppColors.textGrey, size: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Environment Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.8, 
                children: [
                  EnvCompactTile(label: "Temperature", value: _temp, icon: Icons.thermostat_rounded, accentColor: const Color(0xFFFACC15)),
                  EnvCompactTile(label: "Humidity", value: _humidity, icon: Icons.water_drop_rounded, accentColor: const Color(0xFF3B82F6)),
                  EnvCompactTile(label: "Air Quality", value: _aqiLabel, icon: Icons.air_rounded, accentColor: _aqiColor, valueColor: _aqiColor),
                  EnvCompactTile(label: "Noise Level", value: _noiseLabel, icon: Icons.graphic_eq_rounded, accentColor: _noiseColor, valueColor: _noiseColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}