import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdStorage {
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'device_id';
  static final Random _random = Random.secure();

  static Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final deviceId = _uuidV4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final chars = bytes.map(hex).join();
    return '${chars.substring(0, 8)}-'
        '${chars.substring(8, 12)}-'
        '${chars.substring(12, 16)}-'
        '${chars.substring(16, 20)}-'
        '${chars.substring(20)}';
  }
}
