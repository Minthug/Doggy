import 'package:doggy/features/walk/domain/providers/walk_active_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime(2026, 10, 29, 12);
  final lastPoint = WalkPoint(
    lat: 37.218000,
    lng: 126.944000,
    recordedAt: startedAt,
    accuracy: 5,
  );

  test('정확한 위치에서 5초간 머물면 정지 샘플을 기록한다', () {
    expect(
      shouldRecordStationarySample(
        lastPoint: lastPoint,
        currentLat: 37.218001,
        currentLng: 126.944001,
        currentAccuracy: 8,
        positionRecordedAt: startedAt,
        now: startedAt.add(const Duration(seconds: 5)),
      ),
      isTrue,
    );
  });

  test('이동 중이거나 GPS 오차가 크면 정지 샘플을 기록하지 않는다', () {
    expect(
      shouldRecordStationarySample(
        lastPoint: lastPoint,
        currentLat: 37.218200,
        currentLng: 126.944000,
        currentAccuracy: 8,
        positionRecordedAt: startedAt,
        now: startedAt.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
    expect(
      shouldRecordStationarySample(
        lastPoint: lastPoint,
        currentLat: 37.218001,
        currentLng: 126.944001,
        currentAccuracy: 60,
        positionRecordedAt: startedAt,
        now: startedAt.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
  });

  test('GPS 업데이트가 끊긴 위치는 정지 샘플로 재사용하지 않는다', () {
    expect(
      shouldRecordStationarySample(
        lastPoint: lastPoint,
        currentLat: 37.218001,
        currentLng: 126.944001,
        currentAccuracy: 8,
        positionRecordedAt: startedAt,
        now: startedAt.add(const Duration(seconds: 30)),
      ),
      isFalse,
    );
  });
}
