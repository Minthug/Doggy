import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_storage.dart';

class LocalCache {
  static const _prefix = 'cache_';

  static Future<String?> currentUserKey(String key) async =>
      userKey(key, await TokenStorage.getAccessToken());

  static String? userKey(String key, String? accessToken) {
    if (accessToken == null) return null;
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final userId = payload['sub'];
      if (userId is! String || !RegExp(r'^[0-9]{1,19}$').hasMatch(userId)) {
        return null;
      }
      return '${userId}_$key';
    } catch (_) {
      return null;
    }
  }

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
