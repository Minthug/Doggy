import 'package:flutter/foundation.dart';

const apiBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://223.130.158.221.nip.io:8080',
);

const _allowInsecureHttp = bool.fromEnvironment(
  'ALLOW_INSECURE_HTTP',
  defaultValue: false,
);

String validatedApiBaseUrl() {
  final uri = Uri.parse(apiBaseUrl);
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw StateError('BASE_URL must be an absolute URL');
  }

  final isHttp = uri.scheme == 'http';
  if (isHttp && !(kDebugMode && _allowInsecureHttp)) {
    throw StateError(
      'Insecure HTTP BASE_URL is only allowed in debug builds with '
      'ALLOW_INSECURE_HTTP=true',
    );
  }

  return apiBaseUrl;
}
