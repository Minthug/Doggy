import 'package:dio/dio.dart';
import 'package:doggy/features/walk/data/repositories/walk_repository.dart';
import 'package:doggy/features/walk/domain/providers/walk_active_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GPS UTC 시각은 서버에 현지 시각으로 보낸다', () async {
    final gpsTime = DateTime.utc(2026, 11, 16, 7, 26, 30);
    final expected = gpsTime.toLocal().toIso8601String().substring(0, 19);
    final point = WalkPoint(lat: 37.218, lng: 126.944, recordedAt: gpsTime);
    expect(point.toJson()['recordedAt'], expected);

    Map<String, dynamic>? body;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            body = options.data as Map<String, dynamic>;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );

    await expectLater(
      WalkRepository(dio).complete(sessionId: 1, points: [], endedAt: gpsTime),
      throwsA(isA<DioException>()),
    );
    expect(body?['endedAt'], expected);
  });
}
