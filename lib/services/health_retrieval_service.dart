import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/health_point.dart';

class HealthRetrievalService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton Pattern
  static final HealthRetrievalService _instance = HealthRetrievalService._internal();
  factory HealthRetrievalService() => _instance;
  HealthRetrievalService._internal();

  // =========================================================
  // 1. DASHBOARD STREAMS (Real-time)
  // =========================================================
  
  /// Listens to today's metrics. 
  /// Streams directly from the health_metrics table using supported Realtime filters.
  Stream<Map<String, dynamic>> streamTodaySummary() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value({});

    // Start of today in UTC (since database stores in UTC)
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

    return _supabase
        .from('health_metrics')
        .stream(primaryKey: ['id'])
        .eq('firebase_uid', uid) // Realtime supports 'eq' perfectly
        .order('recorded_at', ascending: false) // Get the newest data first
        .limit(100) // Prevent memory overload by only watching the latest 100 rows
        .map((rows) {
          Map<String, dynamic> summary = {};
          
          // 1. Filter for ONLY today's records locally in Dart
          final todayRows = rows.where((row) {
            final recordedAt = row['recorded_at'] as String;
            return recordedAt.compareTo(todayStart) >= 0;
          }).toList();
          
          // 2. Sort ascending so newest values overwrite older ones in the map
          todayRows.sort((a, b) => (a['recorded_at'] as String).compareTo(b['recorded_at'] as String));
          
          // 3. Build the summary map: {'steps': 5000, 'hr': 72}
          for (var row in todayRows) {
            final mId = row['metric_id'] as String;
            final val = row['value'] ?? row['complex_value']; // Pick whichever is not null
            summary[mId] = val;
          }
          
          return summary;
        });
  }

  
  // =========================================================
  // 2. HISTORY FETCH (Analytics / Graphs)
  // =========================================================

  /// Fetches historical data directly using standard SQL filtering.
  Future<List<HealthPoint>> fetchHistory({
    required String metricId,
    required DateTime start,
    required DateTime end,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      // Clean, simple SQL query
      final rows = await _supabase
          .from('health_metrics')
          .select('value, complex_value, recorded_at')
          .eq('firebase_uid', uid)
          .eq('metric_id', metricId)
          .gte('recorded_at', start.toUtc().toIso8601String())
          .lte('recorded_at', end.toUtc().toIso8601String())
          .order('recorded_at', ascending: true); 

      return rows.map((row) {
        return HealthPoint(
          id: metricId,
          value: row['value'] ?? row['complex_value'],
          // Convert database UTC back to the user's Local Timezone for the graph
          timestamp: DateTime.parse(row['recorded_at']).toLocal(),
        );
      }).toList();

    } catch (e) {
      print("❌ [Retrieval] Graph History Error: $e");
      return [];
    }
  }

  // =========================================================
  // 3. CONSISTENCY HEATMAP (Profile Screen)
  // =========================================================

  /// Fetches activity dates for the Profile Heatmap.
  Future<List<DateTime>> getConsistencyDates(int pastDays) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final startDate = DateTime.now().subtract(Duration(days: pastDays)).toUtc().toIso8601String();

    try {
      // Get all metric events from the past X days
      final rows = await _supabase
          .from('health_metrics')
          .select('metric_id, recorded_at')
          .eq('firebase_uid', uid)
          .gte('recorded_at', startDate);

      // Group locally by Local Time 'YYYY-MM-DD' to find unique metrics per day
      Map<String, Set<String>> dailyMetrics = {};

      for (var row in rows) {
        final dateStr = row['recorded_at'] as String;
        final mId = row['metric_id'] as String;
        
        // Ensure we calculate the "Day" based on the user's timezone, not UTC
        final localDate = DateTime.parse(dateStr).toLocal();
        final dayKey = "${localDate.year}-${localDate.month}-${localDate.day}";
        
        // Add metric to this day's Set (Set automatically prevents duplicates)
        dailyMetrics.putIfAbsent(dayKey, () => {}).add(mId);
      }

      // Rebuild the Heatmap array
      List<DateTime> activityPoints = [];
      
      dailyMetrics.forEach((dayKey, metricsSet) {
        final dateParts = dayKey.split('-');
        final date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
        
        // 1-2 metrics = Light, 3-4 = Medium, 5+ = Dark (Determined by list frequency)
        int intensity = metricsSet.length;
        for (int i = 0; i < intensity; i++) {
          activityPoints.add(date);
        }
      });

      return activityPoints;

    } catch (e) {
      print("❌ [Retrieval] Error fetching consistency: $e");
      return [];
    }
  }

  /// Fetches the raw health metrics from Supabase for the AI Engine.
  /// Grabs everything from the exact current time minus 24 hours.
  Future<List<Map<String, dynamic>>> get24HourHistory(String userId) async {
    try {
      // 1. Calculate the exact timestamp for 24 hours ago
      final DateTime now = DateTime.now().toUtc();
      final DateTime yesterday = now.subtract(const Duration(hours: 24));
      
      // 2. Query Supabase
      // Assuming you initialized Supabase somewhere like Supabase.instance.client
      // and your table is named 'health_metrics'
      final response = await Supabase.instance.client
          .from('health_metrics')
          .select('metric_id, value, complex_value, recorded_at') // Only grab what the AI needs
          .eq('firebase_uid', userId)
          .gte('recorded_at', yesterday.toIso8601String())
          .order('recorded_at', ascending: true); // AI needs chronological order

      // 3. Return as the expected List of Maps
      return List<Map<String, dynamic>>.from(response);
      
    } catch (e) {
      print("🚨 Supabase 24h History Fetch Error: $e");
      return []; // Return an empty list so the app doesn't crash, AI will handle imputation
    }
  }
}