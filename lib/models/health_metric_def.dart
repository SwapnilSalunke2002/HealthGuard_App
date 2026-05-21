import 'package:flutter/material.dart';

/// Defines how we aggregate data for this metric
enum AggregationType {
  latest, // Default: Just show the last recorded value (e.g., Weight)
  sum,    // Add them up (e.g., Water, Calories, Steps)
  average // Calculate mean (e.g., Heart Rate for the day)
}

/// Defines the category for UI grouping
enum MetricCategory {
  vital,
  lab,
  nutrition,
  activity,
  other, environment
}

/// Defines the Time-Bucket strategy for Firestore
enum BucketSize {
  atomic, // Store every event as a separate document (High fidelity, expensive)
  hour,   // 1 Document per Hour
  day,    // 1 Document per Day (Best for Steps, Heart Rate)
  month,  // 1 Document per Month
  year    // 1 Document per Year (Best for Weight, Labs, BP)
}

class HealthMetricDef {
  final String id;
  final String label;
  final String unit;
  final MetricCategory category;
  final IconData icon;
  final Color color;
  final AggregationType aggregation;
  final BucketSize bucketSize;
  final bool isSelectable; // False for internal metrics like 'bp_sys'

  const HealthMetricDef({
    required this.id,
    required this.label,
    required this.unit,
    required this.category,
    required this.icon,
    required this.color,
    this.aggregation = AggregationType.latest,
    this.bucketSize = BucketSize.year, // Default to Year (Low freq)
    this.isSelectable = true,
  });

  /// Factory to load from remote config (Firestore)
  factory HealthMetricDef.fromMap(String id, Map<String, dynamic> map) {
    return HealthMetricDef(
      id: id,
      label: map['label'] ?? 'Unknown',
      unit: map['unit'] ?? '',
      category: _parseCategory(map['category']),
      icon: _parseIcon(map['icon']),
      color: Color(map['color'] ?? 0xFF000000),
      aggregation: _parseAggregation(map['aggregation']),
      bucketSize: _parseBucket(map['bucket']),
      isSelectable: map['isSelectable'] ?? true,
    );
  }

  // --- PARSERS ---
  
  static MetricCategory _parseCategory(String? cat) {
    switch (cat) {
      case 'vital': return MetricCategory.vital;
      case 'lab': return MetricCategory.lab;
      case 'nutrition': return MetricCategory.nutrition;
      case 'activity': return MetricCategory.activity;
      default: return MetricCategory.other;
    }
  }

  static AggregationType _parseAggregation(String? agg) {
    switch (agg) {
      case 'sum': return AggregationType.sum;
      case 'avg': return AggregationType.average;
      default: return AggregationType.latest;
    }
  }

  static BucketSize _parseBucket(String? bucket) {
    switch (bucket) {
      case 'atomic': return BucketSize.atomic;
      case 'hour': return BucketSize.hour;
      case 'day': return BucketSize.day;
      case 'month': return BucketSize.month;
      case 'year': return BucketSize.year;
      default: return BucketSize.year;
    }
  }

  // Basic Icon Mapper (expand as needed for remote config)
  static IconData _parseIcon(String? iconName) {
    switch (iconName) {
      case 'heart': return Icons.favorite;
      case 'water': return Icons.local_drink;
      case 'fire': return Icons.local_fire_department;
      default: return Icons.timeline;
    }
  }
}