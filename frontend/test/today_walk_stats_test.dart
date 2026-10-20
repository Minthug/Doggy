import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('서버의 가족 오늘 산책 집계를 파싱한다', () {
    final stats = TodayWalkStats.fromJson({
      'totalDistanceMeters': 1500,
      'totalDurationSeconds': 900,
      'walkCount': 2,
    });

    expect(stats.totalDistanceMeters, 1500);
    expect(stats.totalDurationSeconds, 900);
    expect(stats.walkCount, 2);
    expect(stats.distanceText, '1.5km');
    expect(stats.durationText, '15분');
  });

  test('누락된 집계 값은 0으로 처리한다', () {
    final stats = TodayWalkStats.fromJson(const {});

    expect(stats.totalDistanceMeters, 0);
    expect(stats.totalDurationSeconds, 0);
    expect(stats.walkCount, 0);
  });
}
