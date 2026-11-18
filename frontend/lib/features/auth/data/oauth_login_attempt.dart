import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OAuthLoginAttempt {
  static const _storage = FlutterSecureStorage();
  static const _key = 'pending_oauth_login';
  static const _lifetime = Duration(minutes: 10);
  static bool _consuming = false;

  static Future<String> begin() async {
    final random = Random.secure();
    final verifier = base64Url
        .encode(List<int>.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'verifier': verifier,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    return challengeFor(verifier);
  }

  static String challengeFor(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');

  static Future<String?> takeVerifier(String? challenge) async {
    if (challenge == null || _consuming) return null;
    _consuming = true;
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final pending = jsonDecode(raw) as Map<String, dynamic>;
      final verifier = pending['verifier'];
      final createdAt = pending['createdAt'];
      if (verifier is! String ||
          createdAt is! int ||
          DateTime.now().millisecondsSinceEpoch - createdAt >
              _lifetime.inMilliseconds) {
        await clear();
        return null;
      }
      if (challengeFor(verifier) != challenge) return null;
      await clear();
      return verifier;
    } catch (_) {
      await clear();
      return null;
    } finally {
      _consuming = false;
    }
  }

  static Future<void> clear() => _storage.delete(key: _key);
}
