import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static final SharedPrefsService _instance = SharedPrefsService._internal();
  factory SharedPrefsService() => _instance;
  SharedPrefsService._internal();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- STRING ---
  Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  String getString(String key, {String defaultValue = ''}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  // --- INT ---
  Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  // --- BOOLEAN ---
  Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  // --- LIST ---
  Future<bool> setList(String key, List<String> value) async {
    return await _prefs?.setStringList(key, value) ?? false;
  }

  List<String> getList(String key) {
    return _prefs?.getStringList(key) ?? [];
  }

  // --- MAP ---
  Future<bool> setMap(String key, Map<String, dynamic> value) async {
    try {
      String jsonString = jsonEncode(value);
      return await _prefs?.setString(key, jsonString) ?? false;
    } catch (e) {
      print("SharedPrefs Error (setMap): $e");
      return false;
    }
  }

  Map<String, dynamic> getMap(String key) {
    String? jsonString;
    try {
      // 1. Try to read as String
      jsonString = _prefs?.getString(key);
    } catch (e) {
      // 2. If it fails (e.g., it was stored as an Int), clear it!
      print("⚠️ [SharedPrefs] Key '$key' has wrong type. Clearing...");
      _prefs?.remove(key); 
      return {};
    }

    if (jsonString == null || jsonString.isEmpty) return {};

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print("❌ [SharedPrefs] JSON Parse Error: $e");
      return {};
    }
  }

  // Add inside SharedPrefsService class if missing
  Future<bool> setDouble(String key, double value) async => await _prefs?.setDouble(key, value) ?? false;
  double getDouble(String key, {double defaultValue = 0.0}) => _prefs?.getDouble(key) ?? defaultValue;

  // --- UTILITIES ---
  Future<bool> remove(String key) async => await _prefs?.remove(key) ?? false;
  Future<bool> clearAll() async => await _prefs?.clear() ?? false;
  bool containsKey(String key) => _prefs?.containsKey(key) ?? false;
}