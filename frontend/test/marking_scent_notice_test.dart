import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/features/walk/presentation/widgets/marking_scent_notice.dart';

void main() {
  final now = DateTime.parse('2026-11-26T12:00:00+09:00');
  String? notice(String? visit, [String? rain]) =>
      markingScentNotice(lastVisitedAt: visit, lastRainAt: rain, now: now);
  test('3일 경계에서만 시간 경과를 안내한다', () {
    expect(notice('2026-11-23T12:00:01'), isNull);
    expect(notice('2026-11-23T12:00:00'), contains('3일 이상'));
  });
  test('마킹 후에 관측한 비만 반영한다', () {
    expect(
      notice('2026-11-26T09:00:00', '2026-11-26T10:00:00'),
      contains('비가 관측'),
    );
    expect(notice('2026-11-26T11:00:00', '2026-11-26T10:00:00'), isNull);
    expect(notice('2026-11-26T09:00:00', '2026-11-27T10:00:00'), isNull);
  });
  test('비가 오면 흐려지고 비 이후 새 마킹이면 원래 선명도로 표시한다', () {
    expect(
      markingScentOpacity(
        lastVisitedAt: '2026-11-26T09:00:00',
        lastRainAt: '2026-11-26T10:00:00',
        now: now,
      ),
      0.65,
    );
    expect(
      markingScentOpacity(
        lastVisitedAt: '2026-11-26T11:00:00',
        lastRainAt: '2026-11-26T10:00:00',
        now: now,
      ),
      1,
    );
    expect(
      markingScentOpacity(lastVisitedAt: '2026-11-23T12:00:00', now: now),
      0.65,
    );
  });
  test('비와 3일 경과가 겹치면 가장 옅게 표시한다', () {
    expect(
      markingScentOpacity(
        lastVisitedAt: '2026-11-22T12:00:00',
        lastRainAt: '2026-11-25T12:00:00',
        now: now,
      ),
      0.35,
    );
  });
  test('시각 누락이나 오류를 신선한 냄새로 단정하지 않는다', () {
    expect(notice(null), isNull);
    expect(notice('invalid'), isNull);
    expect(notice('2026-11-26T11:00:00'), isNull);
  });
}
