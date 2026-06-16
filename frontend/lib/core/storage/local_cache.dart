import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const _prefix = 'cache_';

  static Future<void> write(String key, dynamic json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + key, jsonEncode(json));
  }

  static Future<dynamic> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + key);
  }
}
