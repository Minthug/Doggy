import 'dart:io';

class AppMetadata {
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static String get platform {
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    return 'unknown';
  }

  static Map<String, String> headers() {
    return {'X-App-Version': version, 'X-App-Platform': platform};
  }
}
