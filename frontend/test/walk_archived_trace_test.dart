import 'package:doggy/features/walk/presentation/screens/walk_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기존 보관 흔적은 하나의 경로로 복원한다', () {
    final segments = decodeTracePathSegments('v1|100,100;10,0;0,10');
    expect(segments, hasLength(1));
    expect(segments.single, hasLength(3));
  });

  test('일시정지된 보관 흔적은 두 경로로 복원한다', () {
    final segments = decodeTracePathSegments('v2|70,443;287,0|643,157;287,0');
    expect(segments, hasLength(2));
    expect(segments.first.last.dx, 357);
    expect(segments.last.first.dx, 643);
  });
}
