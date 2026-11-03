import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:doggy/core/api/api_client.dart';
import 'package:doggy/core/storage/token_storage.dart';
import 'package:doggy/main.dart' show navigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DioException unauthorized(String path, {bool retried = false}) {
    final request = RequestOptions(
      path: path,
      extra: {'_retriedAfterRefresh': retried},
    );
    return DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
    );
  }

  test('인증 요청의 401은 토큰 재발급을 시도하지 않는다', () {
    expect(shouldRefreshToken(unauthorized('/api/auth/login')), isFalse);
    expect(shouldRefreshToken(unauthorized('/api/auth/signup')), isFalse);
  });

  test('일반 요청의 401은 한 번만 토큰 재발급을 시도한다', () {
    expect(shouldRefreshToken(unauthorized('/api/users/me')), isTrue);
    expect(
      shouldRefreshToken(unauthorized('/api/users/me', retried: true)),
      isFalse,
    );
  });

  test('로그인 401은 기존 재발급 토큰을 건드리지 않는다', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'old-access',
      'refresh_token': 'old-refresh',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)
      ..httpClientAdapter = _StatusAdapter(401);

    await expectLater(
      dio.post('/api/auth/login', data: {'email': 'wrong@example.com'}),
      throwsA(isA<DioException>()),
    );
    expect(await TokenStorage.getRefreshToken(), 'old-refresh');
  });

  test('저장된 토큰이 없으면 로그인 화면으로 진입한다', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await hasValidSession(container.read(dioProvider)), isFalse);
  });

  testWidgets('보호된 API가 401이면 저장된 토큰을 지우고 로그인으로 이동한다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'expired'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)
      ..httpClientAdapter = _StatusAdapter(401);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('홈 화면')),
        routes: {'/login': (_) => const Scaffold(body: Text('로그인 화면'))},
      ),
    );

    expect(await tester.runAsync(() => hasValidSession(dio)), isFalse);
    await tester.pumpAndSettle();
    expect(await TokenStorage.getAccessToken(), isNull);
    expect(find.text('로그인 화면'), findsOneWidget);
  });

  test('보호된 API가 성공하면 세션을 유지한다', () async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'valid'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)
      ..httpClientAdapter = _StatusAdapter(200);

    expect(await hasValidSession(dio), isTrue);
    expect(await TokenStorage.getAccessToken(), 'valid');
  });

  test('서버 오류는 세션을 지우지 않는다', () async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'valid'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)
      ..httpClientAdapter = _StatusAdapter(500);

    expect(await hasValidSession(dio), isTrue);
    expect(await TokenStorage.getAccessToken(), 'valid');
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', statusCode);

  @override
  void close({bool force = false}) {}
}
