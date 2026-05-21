import 'dart:async';
import 'dart:io';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'shared_prefs_service.dart';
import 'health_ingestion_service.dart'; // <--- IMPORT THIS
import '../data/health_ids.dart';       // <--- IMPORT THIS

class StepService {
  static final StepService _instance = StepService._internal();
  factory StepService() => _instance;
  StepService._internal();

  // --- STREAMS ---
  final StreamController<int> _stepController = StreamController.broadcast();
  final StreamController<String> _statusController = StreamController.broadcast();

  Stream<int> get stepStream => _stepController.stream;
  Stream<String> get statusStream => _statusController.stream;

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  // --- TRACKING STATE ---
  int _savedStepsAtMidnight = 0;
  String _lastSavedDate = "";
  final SharedPrefsService _prefs = SharedPrefsService();

  // --- DB THROTTLING (To save money & battery) ---
  int _lastDbValue = 0;
  DateTime _lastDbTime = DateTime.now().subtract(const Duration(minutes: 10));

  Future<bool> init() async {
    bool granted = await _checkPermission();
    if (granted) {
      await _loadDailyOffset(); 
      _startListening();
      return true;
    } else {
      _statusController.add("Unknown");
      return false;
    }
  }

  // --- PERMISSION REQUESTER ---
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (status.isGranted) {
        await _loadDailyOffset();
        _startListening();
        return true;
      }
      return false;
    }
    return true; 
  }

  Future<bool> _checkPermission() async {
    if (Platform.isAndroid) {
      return await Permission.activityRecognition.status.isGranted;
    }
    return true;
  }

  // --- INTERNAL LOGIC ---
  Future<void> _loadDailyOffset() async {
    // Ensure Prefs is ready before reading
    await SharedPrefsService.init();
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    _lastSavedDate = _prefs.getString('step_date');
    int storedOffset = _prefs.getInt('step_offset', defaultValue: -1);

    if (_lastSavedDate != today) {
      _savedStepsAtMidnight = -1; 
    } else {
      _savedStepsAtMidnight = storedOffset;
    }
  }

  Future<void> _saveDailyOffset(int currentSensorValue) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _savedStepsAtMidnight = currentSensorValue;
    _lastSavedDate = today;

    await _prefs.setString('step_date', today);
    await _prefs.setInt('step_offset', currentSensorValue);
  }

  void _startListening() {
    _stepCountSubscription?.cancel();
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (event) {
        _processStepEvent(event.steps);
      },
      onError: (error) {
        print("Step Error: $error");
        _stepController.add(0); 
      },
    );

    _pedestrianStatusSubscription?.cancel();
    _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
      (event) => _statusController.add(event.status),
      onError: (_) => _statusController.add("Unknown"),
    );
  }

  void _processStepEvent(int sensorSteps) {
    // 1. Handle Reboot (Sensor resets to 0)
    if (sensorSteps < _savedStepsAtMidnight) {
      _savedStepsAtMidnight = 0;
      _saveDailyOffset(0);
    }

    // 2. Handle New Day
    if (_savedStepsAtMidnight == -1) {
      _saveDailyOffset(sensorSteps);
    }

    // 3. Calculate Today's Steps
    int todaySteps = sensorSteps - _savedStepsAtMidnight;
    if (todaySteps < 0) todaySteps = 0;

    // 4. Update UI Stream (Instant)
    _stepController.add(todaySteps);

    // 5. [NEW] Smart Cloud Sync
    _syncToFirestore(todaySteps);
  }

  /// Only writes to Firestore if:
  /// - Steps changed by > 50 since last write
  /// - OR > 5 minutes have passed since last write
  void _syncToFirestore(int currentSteps) {
    if (currentSteps == 0) return;

    final now = DateTime.now();
    final diffSteps = (currentSteps - _lastDbValue).abs();
    final diffTime = now.difference(_lastDbTime);

    if (diffSteps >= 50 || diffTime.inMinutes >= 5) {
      print("☁️ Syncing Steps to DB: $currentSteps");
      
      HealthIngestionService().logHealthData(
        metricId: HealthID.steps, 
        value: currentSteps,
        timestamp: now
      );

      _lastDbValue = currentSteps;
      _lastDbTime = now;
    }
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    _stepController.close();
    _statusController.close();
  }
}