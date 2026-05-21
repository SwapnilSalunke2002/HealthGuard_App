import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared_prefs_service.dart';
import '../health_ingestion_service.dart'; // <--- NEW IMPORT
import '../../data/health_ids.dart';

class SilentHealthService {
  static final SilentHealthService _instance = SilentHealthService._internal();
  factory SilentHealthService() => _instance;
  SilentHealthService._internal();

  final SharedPrefsService _prefs = SharedPrefsService();
  final HealthIngestionService _ingestion = HealthIngestionService(); // <--- USE THIS
  StreamSubscription<StepCount>? _stepSubscription;

  // Internal keys
  static const String _keyStepsOffset = "internal_steps_offset";
  static const String _keyLastStepDate = "internal_last_step_date";

  Future<void> init() async {
    _initPedometer();
    print("❤️ [SilentHealth] Sensor Listening Started");
  }

  void _initPedometer() {
    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (e) => print("❤️ [SilentHealth] Pedometer Error: $e"),
    );
  }

  Future<void> _onStepCount(StepCount event) async {
    int totalSensorSteps = event.steps;
    String today = DateTime.now().toIso8601String().split('T')[0];
    String lastDate = _prefs.getString(_keyLastStepDate);
    int offset = _prefs.getInt(_keyStepsOffset);

    // Midnight Reset Logic
    if (lastDate != today) {
      offset = totalSensorSteps;
      await _prefs.setInt(_keyStepsOffset, offset);
      await _prefs.setString(_keyLastStepDate, today);
    }

    int dailySteps = totalSensorSteps - offset;
    if (dailySteps < 0) dailySteps = 0;

    await _prefs.setInt(HealthID.steps, dailySteps);
  }

  /// 3. Background Sync Logic
  /// NOW USES HealthIngestionService
  Future<void> performBackgroundSync() async {
    // 1. Re-init Prefs (Background Isolate)
    await SharedPrefsService.init(); 
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int steps = _prefs.getInt(HealthID.steps);

    if (steps > 0) {
      // 2. Delegate to Ingestion Service
      // This will handle Bucketing (History) and Summary (Dashboard)
      await _ingestion.logHealthData(
        metricId: HealthID.steps,
        value: steps,
        timestamp: DateTime.now(),
      );
      
      print("🚀 [SilentHealth] Synced $steps steps via Ingestion Service");
    }
  }
}