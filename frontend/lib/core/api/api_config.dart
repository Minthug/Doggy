import 'package:flutter/foundation.dart';

const apiBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://223.130.158.221.nip.io',
);

const _allowInsecureHttp = bool.fromEnvironment(
  'ALLOW_INSECURE_HTTP',
  defaultValue: false,
);

String validatedApiBaseUrl([String baseUrl = apiBaseUrl]) {
  final uri = Uri.parse(baseUrl);
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw StateError('BASE_URL must be an absolute URL');
  }

  if (uri.scheme != 'https' &&
      !(uri.scheme == 'http' && kDebugMode && _allowInsecureHttp)) {
    throw StateError(
      'BASE_URL must use HTTPS, except HTTP in debug builds with '
      'ALLOW_INSECURE_HTTP=true',
    );
  }

  return baseUrl;
}
