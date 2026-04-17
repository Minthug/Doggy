import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'in_app_banner.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 수신 시 시스템이 자동 표시 (별도 처리 불필요)
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(dioProvider));
});

class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final dynamic _dio;
  GlobalKey<NavigatorState>? _navigatorKey;

  FcmService(this._dio);

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> initialize() async {
    await _initLocalNotifications();

    // 알림 권한 요청
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS: 포그라운드에서 badge/sound만 허용, alert는 InAppBanner가 처리
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 포그라운드 메시지 처리 (Android는 로컬 알림, iOS는 위 옵션으로 자동 표시)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    await _registerToken();
    _messaging.onTokenRefresh.listen(_sendTokenToServer);
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Android 알림 채널 생성 (앱 시작 시 미리 등록해야 백그라운드도 적용)
    const channels = [
      AndroidNotificationChannel(
        'ping',
        '근처 강아지 알림',
        description: '주변 50m 내 산책 중인 강아지 알림',
        importance: Importance.max,        // heads-up (카카오톡 스타일)
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'walk_reminder',
        '산책 리마인더',
        description: '산책 미완료 리마인더 알림',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'weather',
        '날씨 알림',
        description: '산책 적합 날씨 알림',
        importance: Importance.defaultImportance,
        playSound: false,
      ),
      AndroidNotificationChannel(
        'achievement',
        '달성 알림',
        description: '월간 산책 목표 달성 알림',
        importance: Importance.high,
        playSound: true,
      ),
    ];

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in channels) {
      await androidPlugin?.createNotificationChannel(channel);
    }
  }

  Future<void> _registerToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? apnsToken;
      for (int i = 0; i < 10; i++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
      if (apnsToken == null) return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _sendTokenToServer(token);
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await _dio.patch('/api/users/me/fcm-token', data: token);
    } catch (_) {}
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final channelId = message.data['channel'] as String? ?? 'walk_reminder';
    final bannerType = _toBannerType(channelId);

    // 인앱 배너 우선 (iOS/Android 공통)
    // navigatorKey.currentContext는 Navigator 자신의 context라 Overlay 위에 있음
    // → currentState.overlay로 Navigator 내부 Overlay에 직접 접근
    final overlay = _navigatorKey?.currentState?.overlay;
    if (overlay != null) {
      InAppBanner.show(
        overlay: overlay,
        title: notification.title ?? '',
        body: notification.body ?? '',
        type: bannerType,
      );
      return;
    }

    // context 없을 때 Android만 로컬 알림으로 폴백
    // (iOS는 alert:false 설정이므로 별도 처리 불필요)
    if (defaultTargetPlatform != TargetPlatform.android) return;

    debugPrint('[FCM] context 없음 — 로컬 알림으로 폴백 (channelId: $channelId)');
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      importance: channelId == 'ping' ? Importance.max : Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title,
      ),
    );
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails),
    );
  }

  BannerType _toBannerType(String channelId) {
    return switch (channelId) {
      'ping'        => BannerType.ping,
      'weather'     => BannerType.weather,
      'achievement' => BannerType.achievement,
      'walk_reminder' => BannerType.reminder,
      _             => BannerType.general,
    };
  }

  String _channelName(String channelId) {
    return switch (channelId) {
      'ping'         => '근처 강아지 알림',
      'weather'      => '날씨 알림',
      'achievement'  => '달성 알림',
      _              => '산책 리마인더',
    };
  }
}
