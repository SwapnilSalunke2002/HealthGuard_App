import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:HealthGuard/services/task_orchestrator.dart';
import 'package:HealthGuard/services/shared_prefs_service.dart';

// Services
import 'package:HealthGuard/services/silent_monitoring/silent_env_service.dart';
import 'package:HealthGuard/services/silent_monitoring/silent_health_service.dart';
// Note: WeatherService import is REMOVED

class MetricsSyncTask extends BaseTask<void, bool> {
  @override
  String get taskIdentifier => 'com.healthguard.metrics_auto_sync';

  @override
  Future<bool> execute(void params) async {
    try {
      print("⚙️ [MetricsSyncTask] Waking up background worker...");

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(); 
      }
      
      // Init Prefs for the unified services
      await SharedPrefsService.init(); 
      
      // Execute in Parallel
      // SilentEnvService now handles Noise + Weather internally
      final results = await Future.wait([
        _safeRun("Health (Steps)", () => SilentHealthService().performBackgroundSync()),
        _safeRun("Env (Noise/Weather)", () => SilentEnvService().performBackgroundSync()),
      ]);
      
      bool allSuccess = results.every((r) => r == true);

      if (allSuccess) {
        print("✅ [MetricsSyncTask] All jobs finished successfully");
        return true;
      } else {
        print("⚠️ [MetricsSyncTask] Partial success");
        return true; 
      }

    } catch (e) {
      print("❌ [MetricsSyncTask] Critical Failure: $e");
      return false;
    }
  }

  Future<bool> _safeRun(String label, Future<dynamic> Function() task) async {
    try {
      await task();
      return true;
    } catch (e) {
      print("❌ [$label] Sync Failed: $e");
      return false;
    }
  }
}