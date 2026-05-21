import 'dart:convert';

class HealthPoint {
  final String id;        // Metric ID (e.g., 'hr', 'bp')
  final dynamic value;    // The actual recorded value
  final dynamic predictedValue; // NEW: The LSTM's "Digital Twin" prediction
  final DateTime timestamp;

  HealthPoint({
    required this.id,
    required this.value,
    this.predictedValue, // Optional (Not all metrics will run through the AI)
    required this.timestamp,
  });

  /// Helper for Actual Y
  double get y {
    if (value is num) return (value as num).toDouble();
    if (value is String) {
      String strVal = value.toString();
      
      // 1. Is it JSON? (Our new Context Bundle)
      if (strVal.startsWith('{') && strVal.endsWith('}')) {
        try {
          final map = jsonDecode(strVal);
          // Look for 'raw_value' or default to 0
          if (map.containsKey('raw_value')) {
             var raw = map['raw_value'];
             if (raw is num) return raw.toDouble();
             if (raw is String && raw.contains('/')) return double.tryParse(raw.split('/')[0]) ?? 0.0;
             return double.tryParse(raw.toString()) ?? 0.0;
          }
        } catch (_) { return 0.0; }
      }
      
      // 2. Is it a Blood Pressure fraction?
      if (strVal.contains('/')) return double.tryParse(strVal.split('/')[0]) ?? 0.0;
      
      // 3. Just a string number
      return double.tryParse(strVal) ?? 0.0;
    }
    return 0.0;
  }

  /// Helper for Predicted Y (Digital Twin)
  double? get predictedY {
    if (predictedValue == null) return null;
    if (predictedValue is num) return (predictedValue as num).toDouble();
    if (predictedValue is String) {
      if (predictedValue.toString().contains('/')) return double.tryParse(predictedValue.toString().split('/')[0]) ?? 0.0;
      return double.tryParse(predictedValue.toString());
    }
    return null;
  }

  @override
  String toString() => 'HealthPoint($id, Actual: $value, Predicted: $predictedValue, $timestamp)';
}