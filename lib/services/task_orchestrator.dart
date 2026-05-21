import 'dart:async';
// import 'dart:isolate'; // Removed Isolate import as we are running on main thread for Plugins
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../tasks/metrics_sync_task.dart'; // <--- UPDATED IMPORT

// --- BASE TASK INTERFACE ---
abstract class BaseTask<P, R> {
  String get taskIdentifier;
  FutureOr<R> execute(P params);
}

// --- TASK REGISTRY ---
// This map connects the String ID from the OS to the actual Dart Class.
final Map<String, BaseTask> _taskRegistry = {
  // Map the ID to the new Task Class
  'com.healthguard.metrics_auto_sync': MetricsSyncTask(),
};

// --- GLOBAL DISPATCHER (Entry Point) ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final task = _taskRegistry[taskName];
    
    if (task != null) {
      try {
        // Execute the task logic
        await task.execute(null);
        return Future.value(true);
      } catch (e) {
        debugPrint("[Dispatcher] Task $taskName failed: $e");
        return Future.value(false);
      }
    }
    
    return Future.value(true); // Unknown task, acknowledge to OS
  });
}

class TaskOrchestrator {
  static final TaskOrchestrator _instance = TaskOrchestrator._internal();
  factory TaskOrchestrator() => _instance;
  TaskOrchestrator._internal();

  /// Initialize the WorkManager engine
  Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode, // Prints logs to console when true
    );

    // --- AUTO-START SCHEDULE ---
    // Ensure the background job is scheduled as soon as the app starts.
    _scheduleAutomatedMetrics();
  }

  void _scheduleAutomatedMetrics() {
    // 1. We no longer wait until midnight. We sync periodically during the day.
    // 6 hours strikes a perfect balance between battery life and AI awareness.
    
    schedulePeriodic(
      MetricsSyncTask(),
      frequency: const Duration(hours: 6), 
      // initialDelay: Duration.zero, // Start almost immediately
    );
    
    debugPrint("🚀 [Orchestrator] Scheduled AI Telemetry Sync every 6 hours.");
  }

  // ==================================================
  // MODE 1: FOREGROUND CONCURRENCY (Instant)
  // ==================================================
  Future<R> runNow<P, R>(BaseTask<P, R> task, P params) async {
    try {
      // [FIX] REMOVED Isolate.run()
      // Flutter Plugins (Firestore, Geolocator) use Platform Channels.
      // They generally fail inside standard Isolates.
      // Since Network/DB calls are async I/O, they won't freeze the UI 
      // running on the main thread anyway.
      debugPrint("🚀 [Orchestrator] Running ${task.taskIdentifier} immediately...");
      final result = await task.execute(params);
      return result;
    } catch (e) {
      debugPrint("[Orchestrator] Execution Error: $e");
      rethrow;
    }
  }

  // ==================================================
  // MODE 2: BACKGROUND SCHEDULING (Periodic)
  // ==================================================
  Future<void> schedulePeriodic(
    BaseTask task, {
    Duration frequency = const Duration(hours: 2),
    Duration? initialDelay, // <--- Add this parameter
    Map<String, dynamic>? inputData,
  }) async {
    await Workmanager().registerPeriodicTask(
      task.taskIdentifier, 
      task.taskIdentifier, 
      frequency: frequency,
      initialDelay: initialDelay ?? Duration.zero, // <--- Use it here
      inputData: inputData,
      constraints: Constraints(
        networkType: NetworkType.connected, 
        requiresBatteryNotLow: true,        
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update, // Change 'keep' to 'update' to apply the new time immediately
    );
    debugPrint("[Orchestrator] Scheduled ${task.taskIdentifier} every ${frequency.inHours}h");
  }
}