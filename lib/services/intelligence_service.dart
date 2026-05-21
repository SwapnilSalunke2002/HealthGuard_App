// lib/services/intelligence_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIAnalysisResult {
  final int healthScore;
  final double mse;
  final double threshold;
  final double predictedSafeHr;
  final String status;
  final String message;
  final int alertLevel;
  final int calibrationProgress;
  final int calibrationRequired;
  // NEW: Feature Analysis Map
  final Map<String, double> featureAnalysis;

  AIAnalysisResult({
    required this.healthScore,
    required this.mse,
    required this.threshold,
    required this.predictedSafeHr,
    required this.status,
    required this.message,
    required this.alertLevel,
    required this.calibrationProgress,
    required this.calibrationRequired,
    required this.featureAnalysis,
  });

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    // Safely parse the feature_analysis map
    Map<String, double> parsedFeatures = {};
    if (json['feature_analysis'] != null) {
      final Map<String, dynamic> rawFeatures = json['feature_analysis'];
      rawFeatures.forEach((key, value) {
        parsedFeatures[key] = (value as num).toDouble();
      });
    }

    return AIAnalysisResult(
      healthScore: json['health_score'] ?? 100,
      mse: (json['mse'] ?? 0.0).toDouble(),
      threshold: (json['threshold'] ?? 0.0).toDouble(),
      predictedSafeHr: (json['predicted_safe_hr'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'UNKNOWN',
      message: json['message'] ?? 'Unable to parse diagnosis.',
      alertLevel: json['alert_level'] ?? 0,
      calibrationProgress: json['calibration_progress'] ?? 0,
      calibrationRequired: json['calibration_required'] ?? 500,
      featureAnalysis: parsedFeatures,
    );
  }
}

class IntelligenceService {
  static const String _baseUrl = 'https://healthguard-cloud-run-196204001554.asia-south1.run.app/api/v1';

  static Future<AIAnalysisResult?> analyzeVitals({
    required String userId,
    required double currentHeartRate,
    required double currentSpO2,
    required double currentBodyTemp,
    required double currentRespRate,
    required int contextSteps,
    required double contextTemp,
    required double contextRhum,
    required int contextAqi,
    required double weight,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/analyze');

      final Map<String, dynamic> payload = {
        "user_id": userId,
        "current_context": {
          "hr": currentHeartRate,
          "spo2": currentSpO2,
          "body_temp": currentBodyTemp,
          "resp_rate": currentRespRate,
          "context_steps": contextSteps,
          "context_temp": contextTemp,
          "context_rhum": contextRhum,
          "context_aqi": contextAqi,
          "weight": weight,
        }
      };

      print("📡 HealthGuard: Sending micro-payload to Cloud AI Engine...");

      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final result = AIAnalysisResult.fromJson(decodedData);
        
        print("✅ AI Analysis Complete.");
        print("   -> Status: ${result.status}");
        print("   -> Features Analyzed: ${result.featureAnalysis.keys.join(', ')}");
        
        return result;
      } else {
        print("❌ Cloud API Error (${response.statusCode}): ${response.body}");
        return null;
      }
    } catch (e) {
      print("🚨 Failed to connect to AI Engine: $e");
      return null;
    }
  }
}