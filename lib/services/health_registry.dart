import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_metric_def.dart';
import '../data/health_ids.dart';
import '../data/subjective_ids.dart'; 
import '../data/env_ids.dart'; // <--- NEW IMPORT

class HealthRegistry {
  static final Map<String, HealthMetricDef> _cache = {};
  static bool _isInitialized = false;

  // --- INITIALIZATION ---
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // 1. Load defaults first (instant UI availability)
      _loadFallbacks();
      
      // 2. Try to fetch overrides from cloud (optional remote config)
      // This allows you to change a metric's color or label without an app update!
      final snapshot = await FirebaseFirestore.instance.collection('health_definitions').get();
      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          _cache[doc.id] = HealthMetricDef.fromMap(doc.id, doc.data());
        }
      }
      _isInitialized = true;
    } catch (e) {
      // Use defaults if offline/error
      print("⚠️ [Registry] Cloud sync failed, using defaults: $e");
      _isInitialized = true;
    }
  }

  // --- PUBLIC API ---

  // Get specific metric definition
  static HealthMetricDef? get(String id) => _cache[id.toLowerCase()];

  // Search/Filter for UI Lists (e.g. "Add Data" screen)
  static List<HealthMetricDef> search(String query) {
    var list = _cache.values.toList();

    // Filter out strictly internal metrics (if any)
    list = list.where((m) => m.isSelectable).toList();

    if (query.isNotEmpty) {
      final lowerQ = query.toLowerCase();
      list = list.where((m) => 
        m.label.toLowerCase().contains(lowerQ) || 
        m.id.toLowerCase().contains(lowerQ) ||
        m.category.name.contains(lowerQ) // Allow searching by "Lab", "Vital", etc.
      ).toList();
    }
    
    // Sort: Vitals first, then Alphabetical
    list.sort((a, b) {
      if (a.category == MetricCategory.vital && b.category != MetricCategory.vital) return -1;
      if (b.category == MetricCategory.vital && a.category != MetricCategory.vital) return 1;
      return a.label.compareTo(b.label);
    });
    
    return list;
  }

  // Smart ID Resolver (Maps text like "Pulse" -> "hr")
  static String resolveId(String inputId) {
    String clean = inputId.toLowerCase().trim();
    if (_cache.containsKey(clean)) return clean;

    switch (clean) {
      // Vitals
      case 'heart rate': case 'bpm': case 'pulse': return HealthID.heartRate;
      case 'blood pressure': case 'bp': case 'bp_level': return HealthID.bloodPressure;
      case 'temperature': case 'body temp': case 'fever': return HealthID.bodyTemp;
      case 'spo2': case 'oxygen': case 'saturation': return HealthID.spo2;
      case 'weight': case 'body weight': return HealthID.weight;
      case 'height': return HealthID.height;
      
      // Blood / Lab
      case 'hemoglobin': case 'hb': return HealthID.hemoglobin;
      case 'rbc': case 'erythrocytes': return HealthID.rbc;
      case 'wbc': case 'leukocytes': return HealthID.wbc;
      case 'platelets': case 'thrombocytes': return HealthID.platelets;

      // Diabetes / Lipid
      case 'glucose': case 'blood sugar': case 'sugar': case 'rbs': case 'fbs': return HealthID.glucose;
      case 'hba1c': case 'a1c': return HealthID.hba1c;
      case 'cholesterol': return HealthID.cholesterol;
      case 'triglycerides': return HealthID.triglycerides;

      // Lifestyle
      case 'steps': case 'step count': return HealthID.steps;
      case 'calories': case 'cal': case 'kcal': return HealthID.calories;
      case 'sleep': case 'hours slept': return HealthID.sleep;
      case 'water': case 'hydration': return HealthID.water;

      // Environment
      case 'noise': case 'decibel': return EnvID.noiseLevel;
      case 'aqi': case 'air quality': return EnvID.airQuality;
      case 'humidity': return EnvID.humidity;
      case 'ambient temp': case 'weather': return EnvID.ambientTemp;

      // Subjective
      case 'mood': case 'feeling': return SubjectiveID.mood;
      case 'stress': return SubjectiveID.stress;
      case 'pain': return SubjectiveID.pain;
      case 'energy': return SubjectiveID.energy;

      default: return clean;
    }
  }

  // --- FULL DEFAULT DEFINITIONS ---
  static void _loadFallbacks() {
    final List<HealthMetricDef> defaults = [
      HealthMetricDef(
        id: HealthID.systemHealthScore, 
        label: 'Overall Health Score', 
        unit: '/100', 
        category: MetricCategory.vital, 
        icon: Icons.health_and_safety_rounded, 
        color: const Color(0xFF00E5FF), // Neon Blue
        bucketSize: BucketSize.day // Save one score per day
      ),
      
      // ============================================================
      // 1. CORE VITALS
      // ============================================================
      HealthMetricDef(id: HealthID.heartRate, label: 'Heart Rate', unit: 'bpm', category: MetricCategory.vital, icon: Icons.favorite_rounded, color: const Color(0xFFFF5252), bucketSize: BucketSize.day),
      HealthMetricDef(id: HealthID.bloodPressure, label: 'Blood Pressure', unit: 'mmHg', category: MetricCategory.vital, icon: Icons.compress, color: const Color(0xFFFF5252), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.bodyTemp, label: 'Body Temp', unit: '°C', category: MetricCategory.vital, icon: Icons.thermostat_rounded, color: const Color(0xFFFF9800), bucketSize: BucketSize.day),
      HealthMetricDef(id: HealthID.spo2, label: 'Oxygen (SpO2)', unit: '%', category: MetricCategory.vital, icon: Icons.water_drop_rounded, color: const Color(0xFF2196F3), bucketSize: BucketSize.day),
      HealthMetricDef(id: HealthID.weight, label: 'Weight', unit: 'kg', category: MetricCategory.vital, icon: Icons.monitor_weight_rounded, color: const Color(0xFF9C27B0), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.height, label: 'Height', unit: 'cm', category: MetricCategory.vital, icon: Icons.height, color: const Color(0xFF9C27B0), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.respRate, label: 'Resp. Rate', unit: 'br/min', category: MetricCategory.vital, icon: Icons.air_rounded, color: const Color(0xFF00BCD4), bucketSize: BucketSize.day),

      // ============================================================
      // 2. DIABETES
      // ============================================================
      HealthMetricDef(id: HealthID.glucose, label: 'Blood Glucose', unit: 'mg/dL', category: MetricCategory.lab, icon: Icons.water_drop_outlined, color: const Color(0xFFE91E63), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.hba1c, label: 'HbA1c', unit: '%', category: MetricCategory.lab, icon: Icons.pie_chart_rounded, color: const Color(0xFF880E4F), bucketSize: BucketSize.year),

      // ============================================================
      // 3. HEART HEALTH (Lipids)
      // ============================================================
      HealthMetricDef(id: HealthID.cholesterol, label: 'Cholesterol (Total)', unit: 'mg/dL', category: MetricCategory.lab, icon: Icons.fastfood_rounded, color: const Color(0xFFFFC107), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.triglycerides, label: 'Triglycerides', unit: 'mg/dL', category: MetricCategory.lab, icon: Icons.grain_rounded, color: const Color(0xFFFFB300), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.hdl, label: 'HDL (Good)', unit: 'mg/dL', category: MetricCategory.lab, icon: Icons.thumb_up_alt_rounded, color: const Color(0xFF4CAF50), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.ldl, label: 'LDL (Bad)', unit: 'mg/dL', category: MetricCategory.lab, icon: Icons.thumb_down_alt_rounded, color: const Color(0xFFF44336), bucketSize: BucketSize.year),

      // ============================================================
      // 4. BLOOD COUNT (CBC)
      // ============================================================
      HealthMetricDef(id: HealthID.hemoglobin, label: 'Hemoglobin', unit: 'g/dL', category: MetricCategory.lab, icon: Icons.opacity_rounded, color: const Color(0xFFF44336), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.wbc, label: 'WBC Count', unit: '/µL', category: MetricCategory.lab, icon: Icons.shield_outlined, color: const Color(0xFF607D8B), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.platelets, label: 'Platelets', unit: 'k/µL', category: MetricCategory.lab, icon: Icons.grid_view_rounded, color: const Color(0xFFAB47BC), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.rbc, label: 'RBC Count', unit: 'M/µL', category: MetricCategory.lab, icon: Icons.circle_outlined, color: const Color(0xFFEF5350), bucketSize: BucketSize.year),

      // ============================================================
      // 5. ORGANS
      // ============================================================
      HealthMetricDef(id: HealthID.creatinine, label: 'Creatinine', unit: 'mg/dL', category: MetricCategory.lab, icon: Icons.filter_alt_rounded, color: const Color(0xFF795548), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.uricAcid, label: 'Uric Acid', unit: 'mg/dL', category: MetricCategory.lab, icon: Icons.science, color: const Color(0xFF795548), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.sgpt, label: 'SGPT (Liver)', unit: 'U/L', category: MetricCategory.lab, icon: Icons.science, color: const Color(0xFFFFEB3B), bucketSize: BucketSize.year),
      HealthMetricDef(id: HealthID.tsh, label: 'TSH (Thyroid)', unit: 'µIU/mL', category: MetricCategory.lab, icon: Icons.science_rounded, color: const Color(0xFF673AB7), bucketSize: BucketSize.year),

      // ============================================================
      // 6. LIFESTYLE
      // ============================================================
      HealthMetricDef(id: HealthID.steps, label: 'Steps', unit: 'steps', category: MetricCategory.activity, icon: Icons.directions_walk, color: const Color(0xFF4CAF50), aggregation: AggregationType.sum, bucketSize: BucketSize.day),
      HealthMetricDef(id: HealthID.calories, label: 'Calories', unit: 'kcal', category: MetricCategory.nutrition, icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF5722), aggregation: AggregationType.sum, bucketSize: BucketSize.day),
      HealthMetricDef(id: HealthID.water, label: 'Water', unit: 'ml', category: MetricCategory.nutrition, icon: Icons.local_drink_rounded, color: const Color(0xFF2196F3), aggregation: AggregationType.sum, bucketSize: BucketSize.day),
      HealthMetricDef(id: HealthID.sleep, label: 'Sleep', unit: 'hrs', category: MetricCategory.activity, icon: Icons.bedtime_rounded, color: const Color(0xFF673AB7), bucketSize: BucketSize.day),

      // ============================================================
      // 7. ENVIRONMENT
      // ============================================================
      HealthMetricDef(id: EnvID.ambientTemp, label: 'Ambient Temp', unit: '°C', category: MetricCategory.environment, icon: Icons.thermostat_outlined, color: const Color(0xFFFFCA28), bucketSize: BucketSize.day),
      HealthMetricDef(id: EnvID.humidity, label: 'Humidity', unit: '%', category: MetricCategory.environment, icon: Icons.water_drop_outlined, color: const Color(0xFF4FC3F7), bucketSize: BucketSize.day),
      HealthMetricDef(id: EnvID.airQuality, label: 'Air Quality', unit: 'AQI', category: MetricCategory.environment, icon: Icons.air_rounded, color: const Color(0xFF66BB6A), bucketSize: BucketSize.day),
      HealthMetricDef(id: EnvID.noiseLevel, label: 'Noise Level', unit: 'dB', category: MetricCategory.environment, icon: Icons.graphic_eq_rounded, color: const Color(0xFFAB47BC), bucketSize: BucketSize.day),
      HealthMetricDef(id: EnvID.pressure, label: 'Pressure', unit: 'hPa', category: MetricCategory.environment, icon: Icons.speed_rounded, color: const Color(0xFF9E9E9E), bucketSize: BucketSize.day),
      HealthMetricDef(id: EnvID.altitude, label: 'Altitude', unit: 'm', category: MetricCategory.environment, icon: Icons.landscape_rounded, color: const Color(0xFF795548), bucketSize: BucketSize.year),

      // ============================================================
      // 8. SUBJECTIVE
      // ============================================================
      HealthMetricDef(id: SubjectiveID.mood, label: 'Mood', unit: 'lvl', category: MetricCategory.other, icon: Icons.sentiment_satisfied_rounded, color: const Color(0xFFFFC107), bucketSize: BucketSize.year),
      HealthMetricDef(id: SubjectiveID.stress, label: 'Stress', unit: '/10', category: MetricCategory.other, icon: Icons.psychology_rounded, color: const Color(0xFFFF5252), bucketSize: BucketSize.year),
      HealthMetricDef(id: SubjectiveID.energy, label: 'Energy', unit: '/10', category: MetricCategory.other, icon: Icons.bolt_rounded, color: const Color(0xFF00E676), bucketSize: BucketSize.year),
      HealthMetricDef(id: SubjectiveID.pain, label: 'Pain', unit: '/10', category: MetricCategory.other, icon: Icons.healing_rounded, color: const Color(0xFFAB47BC), bucketSize: BucketSize.year),
    ];

    for (var def in defaults) _cache[def.id] = def;
  }
}