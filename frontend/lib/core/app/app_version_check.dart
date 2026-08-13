import 'package:dio/dio.dart';
import '../api/api_config.dart';
import 'app_metadata.dart';

class AppVersionStatus {
  final bool updateRequired;
  final bool updateRecommended;
  final String storeUrl;
  final String message;

  const AppVersionStatus({
    required this.updateRequired,
    required this.updateRecommended,
    required this.storeUrl,
    required this.message,
  });

  factory AppVersionStatus.fromJson(Map<String, dynamic> json) {
    return AppVersionStatus(
      updateRequired: json['updateRequired'] == true,
      updateRecommended: json['updateRecommended'] == true,
      storeUrl: json['storeUrl'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  static const AppVersionStatus current = AppVersionStatus(
    updateRequired: false,
    updateRecommended: false,
    storeUrl: '',
    message: '',
  );
}

class AppVersionCheckClient {
  Future<AppVersionStatus> check() async {
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        '${validatedApiBaseUrl()}/api/app/version',
        options: Options(headers: AppMetadata.headers()),
      );
      final data = response.data;
      if (data == null) {
        return AppVersionStatus.current;
      }
      return AppVersionStatus.fromJson(data);
    } catch (_) {
      return AppVersionStatus.current;
    }
  }
}
