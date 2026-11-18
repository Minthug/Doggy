import 'package:doggy/features/walk/domain/providers/walk_active_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  final startedAt = DateTime(2026, 10, 29, 12);
  final lastPoint = WalkPoint(
    lat: 37.218000,
    lng: 126.944000,
    recordedAt: startedAt,
    accuracy: 5,
  );

  Position fix(DateTime timestamp, {double speed = 0, double lng = 126.944}) =>
      Position(
        latitude: 37.218,
        longitude: lng,
        timestamp: timestamp,
        accuracy: 5,
        altitude: 0,
        heading: 0,
        speed: speed,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

  test('새 GPS 측정값은 정지 중에도 기록할 수 있다', () {
    expect(
      isFreshWalkPosition(
        lastPoint: lastPoint,
        positionRecordedAt: startedAt.add(const Duration(seconds: 5)),
        now: startedAt.add(const Duration(seconds: 5)),
      ),
      isTrue,
    );
  });

  test('같은 GPS 측정값을 다시 받으면 머문 시간으로 쌓지 않는다', () {
    expect(
      isFreshWalkPosition(
        lastPoint: lastPoint,
        positionRecordedAt: startedAt,
        now: startedAt.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
    expect(
      shouldRecordStationaryFix(
        lastPoint: lastPoint,
        position: fix(startedAt),
        now: startedAt.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
  });

  test('새 정지 측정값은 기록하고 이동 중 측정값은 제외한다', () {
    final timestamp = startedAt.add(const Duration(seconds: 5));
    expect(
      shouldRecordStationaryFix(
        lastPoint: lastPoint,
        position: fix(timestamp),
        now: timestamp,
      ),
      isTrue,
    );
    expect(
      shouldRecordStationaryFix(
        lastPoint: lastPoint,
        position: fix(timestamp, speed: 1.5),
        now: timestamp,
      ),
      isFalse,
    );
    expect(
      shouldRecordStationaryFix(
        lastPoint: lastPoint,
        position: fix(timestamp, lng: 126.9442),
        now: timestamp,
      ),
      isFalse,
    );
    expect(
      shouldRecordStationaryFix(
        lastPoint: lastPoint,
        position: fix(timestamp),
        now: timestamp.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
  });

  test('오래되거나 미래의 GPS 측정값은 기록하지 않는다', () {
    expect(
      isFreshWalkPosition(
        lastPoint: lastPoint,
        positionRecordedAt: startedAt.add(const Duration(seconds: 5)),
        now: startedAt.add(const Duration(seconds: 30)),
      ),
      isFalse,
    );
    expect(
      isFreshWalkPosition(
        lastPoint: lastPoint,
        positionRecordedAt: startedAt.add(const Duration(seconds: 30)),
        now: startedAt.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
  });

  test('GPS 점프는 산책 거리에서 제외하고 정상 보행은 기록한다', () {
    final tenSecondsLater = startedAt.add(const Duration(seconds: 10));
    expect(
      shouldRecordWalkPosition(
        lastPoint: lastPoint,
        lat: 35.1,
        lng: 129.0,
        accuracy: 5,
        recordedAt: tenSecondsLater,
      ),
      isFalse,
    );
    expect(
      shouldRecordWalkPosition(
        lastPoint: lastPoint,
        lat: 37.21812,
        lng: 126.944,
        accuracy: 5,
        recordedAt: tenSecondsLater,
      ),
      isTrue,
    );
    expect(
      shouldRecordWalkPosition(
        lastPoint: lastPoint,
        lat: 37.21812,
        lng: 126.944,
        accuracy: 60,
        recordedAt: tenSecondsLater,
      ),
      isFalse,
    );
  });

  test('GPS 오차 범위의 흔들림은 무시하고 실제 이동은 누적한다', () {
    final timestamp = startedAt.add(const Duration(seconds: 10));
    final uncertainPoint = WalkPoint(
      lat: lastPoint.lat,
      lng: lastPoint.lng,
      recordedAt: startedAt,
      accuracy: 20,
    );
    expect(
      shouldRecordWalkPosition(
        lastPoint: uncertainPoint,
        lat: 37.21804,
        lng: lastPoint.lng,
        accuracy: 20,
        recordedAt: timestamp,
      ),
      isFalse,
    );
    expect(
      shouldRecordWalkPosition(
        lastPoint: uncertainPoint,
        lat: 37.21814,
        lng: lastPoint.lng,
        accuracy: 20,
        recordedAt: timestamp,
      ),
      isTrue,
    );
    // Rejected fixes do not move the anchor, so slow walking still accumulates.
    expect(
      shouldRecordWalkPosition(
        lastPoint: uncertainPoint,
        lat: 37.21809,
        lng: lastPoint.lng,
        accuracy: 20,
        recordedAt: timestamp.add(const Duration(seconds: 10)),
      ),
      isTrue,
    );
  });

  test('최근 이동 또는 위치 스트림이 있으면 보조 GPS 요청을 건너뛴다', () {
    final now = startedAt.add(const Duration(seconds: 10));
    expect(
      shouldRequestStationaryFix(
        now: now,
        lastMovingFixAt: now.subtract(const Duration(seconds: 5)),
      ),
      isFalse,
    );
    expect(
      shouldRequestStationaryFix(
        now: now,
        lastMovingFixAt: now.subtract(const Duration(seconds: 10)),
        lastStreamFixAt: now.subtract(const Duration(seconds: 2)),
      ),
      isFalse,
    );
    expect(
      shouldRequestStationaryFix(
        now: now,
        lastMovingFixAt: now.subtract(const Duration(seconds: 10)),
        lastStreamFixAt: now.subtract(const Duration(seconds: 5)),
      ),
      isTrue,
    );
  });

  test('정지 측정값의 시각만 기록하고 GPS 흔들림은 거리로 더하지 않는다', () {
    final timestamp = startedAt.add(const Duration(seconds: 5));
    final point = stationaryWalkPoint(
      lastPoint,
      fix(timestamp, lng: 126.94405),
    );
    expect(point.lat, lastPoint.lat);
    expect(point.lng, lastPoint.lng);
    expect(point.recordedAt, timestamp);
  });
}
