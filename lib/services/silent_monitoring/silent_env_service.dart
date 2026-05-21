import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

// Services
import '../health_ingestion_service.dart';
import '../shared_prefs_service.dart';
import '../../data/env_ids.dart';

class SilentEnvService {
  static final SilentEnvService _instance = SilentEnvService._internal();
  factory SilentEnvService() => _instance;
  SilentEnvService._internal();

  final HealthIngestionService _ingestion = HealthIngestionService();
  final SharedPrefsService _prefs = SharedPrefsService();
  
  // Foreground Resources
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? _noiseMeter;
  bool _isMonitoring = false;

  // ===========================================================================
  // 1. FOREGROUND INIT (Called in main.dart)
  // ===========================================================================
  Future<void> init() async {
    print("🔊 [SilentEnvService] Initializing Foreground Sensors...");
    await _startNoiseMonitoring();
  }

  Future<void> _startNoiseMonitoring() async {
    if (_isMonitoring) return;

    if (await Permission.microphone.request().isGranted) {
      try {
        _noiseMeter = NoiseMeter();
        // NOTE: New package version uses .noise getter
        _noiseSubscription = _noiseMeter?.noise.listen(
          (NoiseReading reading) {
            // Update Cache for Live UI (throttled)
            // We don't save to DB continuously to save battery/storage
            if (DateTime.now().second % 5 == 0) { // Update every 5 seconds
               _prefs.setMap(EnvID.noiseLevel, {
                 'val': reading.meanDecibel, 
                 'ts': DateTime.now().toIso8601String()
               });
            }
          },
          onError: (e) => print("Mic Error: $e"),
        );
        _isMonitoring = true;
      } catch (e) {
        print("❌ [SilentEnvService] Init Failed: $e");
      }
    } else {
      print("⚠️ [SilentEnvService] Mic Permission Denied");
    }
  }

  // ===========================================================================
  // 2. BACKGROUND SYNC (Called by TaskOrchestrator)
  // ===========================================================================
  Future<bool> performBackgroundSync() async {
    try {
      print("🌍 [SilentEnvService] Starting Background Scan...");

      // CRITICAL: Background Tasks run in a separate Isolate.
      // We MUST re-initialize SharedPrefs here because main() didn't run for this isolate.
      await SharedPrefsService.init(); 

      // We ONLY fetch Weather here. 
      // Recording Audio in background is strictly forbidden by OS (privacy).
      final weatherData = await _fetchExternalWeather();

      if (weatherData != null) {
        final now = DateTime.now();
        final ts = now.toIso8601String();

        // 1. Log to Database (History)
        await _ingestion.logHealthData(metricId: EnvID.ambientTemp, value: weatherData['temp'], timestamp: now);
        await _ingestion.logHealthData(metricId: EnvID.humidity, value: weatherData['humidity'], timestamp: now);
        await _ingestion.logHealthData(metricId: EnvID.airQuality, value: weatherData['aqi'], timestamp: now);

        // 2. Update Cache (For Dashboard when user opens app)
        await _prefs.setMap(EnvID.ambientTemp, {'val': weatherData['temp'], 'ts': ts});
        await _prefs.setMap(EnvID.humidity, {'val': weatherData['humidity'], 'ts': ts});
        await _prefs.setMap(EnvID.airQuality, {'val': weatherData['aqi'], 'ts': ts});

        print("✅ [SilentEnvService] Weather Sync Complete: ${weatherData['loc']}");
      }
      
      return true;
    } catch (e) {
      print("❌ [SilentEnvService] Background Failure: $e");
      return false;
    }
  }

  // ===========================================================================
  // 3. WEATHER FETCH LOGIC (Open-Meteo)
  // ===========================================================================
  Future<Map<String, dynamic>?> _fetchExternalWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // In background, "Last Known" is safer & faster than getting a fix
      Position? position = await Geolocator.getLastKnownPosition();
      if (position == null) {
         // Only request fresh if absolutely necessary (battery drain)
         position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      }

      double lat = position.latitude;
      double lon = position.longitude;

      // Get City Name (Optional)
      String cityName = "Unknown";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
        if (placemarks.isNotEmpty) cityName = placemarks[0].locality ?? "Unknown Area";
      } catch (_) {}

      // API Call
      final weatherUrl = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m&timezone=auto';
      final aqiUrl = 'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=us_aqi&timezone=auto';

      final results = await Future.wait([
        http.get(Uri.parse(weatherUrl)),
        http.get(Uri.parse(aqiUrl)),
      ]);

      if (results[0].statusCode != 200 || results[1].statusCode != 200) return null;

      final wData = jsonDecode(results[0].body);
      final aData = jsonDecode(results[1].body);

      return {
        'temp': (wData['current']['temperature_2m'] as num).toDouble(),
        'humidity': (wData['current']['relative_humidity_2m'] as num).toDouble(),
        'aqi': (aData['current']['us_aqi'] as num).toDouble(),
        'loc': cityName
      };

    } catch (e) {
      print("⛈️ [SilentEnvService] Weather API Error: $e");
      return null;
    }
  }
  
  // Cleanup
  void dispose() {
    _noiseSubscription?.cancel();
    _isMonitoring = false;
  }
}