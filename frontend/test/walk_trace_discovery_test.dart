import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/walk/presentation/models/dog_trace_visual.dart';

void main() {
  test('DB 흔적 응답을 강아지 카드와 지도 경로 모델로 변환한다', () {
    final discovery = WalkTraceDiscovery.fromJson({
      'sessionId': 20,
      'recency': 'TODAY',
      'routeGeoJson':
          '{"type":"LineString","coordinates":[[126.9,37.2],[127.0,37.3]]}',
      'dogs': [
        {
          'id': 4,
          'name': '보리',
          'breed': '웰시코기',
          'profileImage': null,
        },
      ],
    });

    expect(discovery.isToday, isTrue);
    expect(discovery.recencyText, '오늘 이 길을 지났어요');
    expect(discovery.dogs.single.name, '보리');

    final visual = buildDogTraceMapItems([discovery]).single;
    expect(visual.id, '20-4');
    expect(visual.name, '보리');
    expect(visual.points, hasLength(2));
    expect(visual.points.first.latitude, 37.2);
    expect(visual.points.first.longitude, 126.9);
  });
}
