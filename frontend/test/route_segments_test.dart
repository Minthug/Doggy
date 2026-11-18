import 'package:doggy/features/walk/presentation/models/route_segments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('일시정지 경로를 연결하지 않고 두 구간으로 읽는다', () {
    final segments = parseRouteSegments('''
      {"type":"MultiLineString","coordinates":[
        [[127.0,37.0],[127.001,37.0]],
        [[128.0,37.0],[128.001,37.0]]
      ]}
    ''');

    expect(segments, hasLength(2));
    expect(segments.first.last.longitude, 127.001);
    expect(segments.last.first.longitude, 128.0);
  });

  test('기존 단일 경로도 한 구간으로 읽는다', () {
    final segments = parseRouteSegments(
      '{"type":"LineString","coordinates":[[127.0,37.0],[127.001,37.0]]}',
    );
    expect(segments, hasLength(1));
    expect(segments.single, hasLength(2));
  });
}
