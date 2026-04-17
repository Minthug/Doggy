import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

// 백그라운드 메시지 핸들러 (top-level 함수 필수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서는 로컬 알림으로 표시
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(dioProvider));
});

class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final dynamic _dio;

  FcmService(this._dio);

  Future<void> initialize() async {
    // 로컬 알림 초기화
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // 알림 권한 요청
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // FCM 토큰 발급 및 서버 등록
    await _registerToken();

    // 토큰 갱신 시 자동 재등록
    _messaging.onTokenRefresh.listen(_sendTokenToServer);
  }

  Future<void> _registerToken() async {
    // iOS: APNs 토큰이 준비될 때까지 최대 10초 대기
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? apnsToken;
      for (int i = 0; i < 10; i++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
      if (apnsToken == null) return; // APNs 미지원 환경(시뮬레이터 등)
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _sendTokenToServer(token);
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await _dio.patch('/api/users/me/fcm-token', data: token);
    } catch (e) {
      // 토큰 등록 실패는 무시 (로그인 전일 수 있음)
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'walk_reminder',
      '산책 알림',
      channelDescription: '산책 리마인더 알림',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
