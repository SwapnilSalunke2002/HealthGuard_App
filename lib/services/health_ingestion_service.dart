import 'dart:convert';
import 'package:HealthGuard/data/env_ids.dart';
import 'package:HealthGuard/data/health_ids.dart';
import 'package:HealthGuard/data/subjective_ids.dart';
import 'package:HealthGuard/services/shared_prefs_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HealthIngestionService {
  // We initialize Supabase and Firebase clients
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- SINGLETON PATTERN ---
  static final HealthIngestionService _instance = HealthIngestionService._internal();
  factory HealthIngestionService() => _instance;
  HealthIngestionService._internal();

  /// **MAIN ENTRY POINT**
  /// Logs a metric directly into the Supabase PostgreSQL database.
  /// 
  /// [metricId]: Use constants from HealthID or EnvID.
  /// [value]: The data point (int, double, String, or Map).
  /// [timestamp]: Defaults to DateTime.now() if null.
  Future<bool> logHealthData({
    required String metricId,
    required dynamic value,
    DateTime? timestamp,
    String? forceUid, // NEW
  }) async {
    try {
      final uid = forceUid ?? _auth.currentUser?.uid; // Use forced UID if provided
      if (uid == null) return false;

      final time = timestamp ?? DateTime.now();
      num? numericValue;
      String? complexValue;

      // --- PAPER 1 FIX: BUNDLE CONTEXT FOR VITALS ---
      // If the metric is a core vital, we fetch the latest environmental
      // data from SharedPrefs and attach it to the payload.
      Map<String, dynamic> contextPayload = {};
      // We now bundle context for BOTH Real-time Vitals AND Subjective Feelings
      final List<String> contextualMetrics = [
        HealthID.heartRate, HealthID.bloodPressure, HealthID.spo2, HealthID.bodyTemp,
        SubjectiveID.mood, SubjectiveID.stress, SubjectiveID.energy, SubjectiveID.pain, SubjectiveID.focus
      ];

      if (contextualMetrics.contains(metricId)) {
         final prefs = SharedPrefsService();
         contextPayload = {
            'context_temp': prefs.getMap(EnvID.ambientTemp)['val'] ?? 20.0,
            'context_rhum': prefs.getMap(EnvID.humidity)['val'] ?? 50.0,
            'context_aqi': prefs.getMap(EnvID.airQuality)['val'] ?? 50,
            'context_steps': prefs.getInt(HealthID.steps),
         };
      }

      if (value is num) {
        numericValue = value;
        // If we have context, we must store it in complex_value as JSON
        if (contextPayload.isNotEmpty) {
           contextPayload['raw_value'] = numericValue;
           complexValue = jsonEncode(contextPayload);
        }
      } else if (value is String) {
        numericValue = num.tryParse(value);
        if (numericValue == null) {
          // It's a complex string like "120/80"
          if (contextPayload.isNotEmpty) {
            contextPayload['raw_value'] = value;
            complexValue = jsonEncode(contextPayload);
          } else {
            complexValue = value;
          }
        } else {
          // It was a string that parsed to a number
          if (contextPayload.isNotEmpty) {
             contextPayload['raw_value'] = numericValue;
             complexValue = jsonEncode(contextPayload);
          }
        }
      }

      await _supabase.from('health_metrics').insert({
        'firebase_uid': uid,
        'metric_id': metricId,
        'value': numericValue, // Still save the raw number for simple graphs
        'complex_value': complexValue, // Stores the bundled JSON context!
        'recorded_at': time.toUtc().toIso8601String(),
      });

      return true;
    } catch (e) {
      print("❌ [Ingestion] Insert Failed: $e");
      return false;
    }
  }
}