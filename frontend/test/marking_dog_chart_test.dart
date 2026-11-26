import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/features/walk/presentation/widgets/marking_dog_chart.dart';
import 'package:doggy/features/walk/presentation/widgets/dog_face_icon.dart';

void main() {
  testWidgets('옅어진 흔적도 강아지 수는 유지하고 얼굴만 흐리게 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkingDogChart(
            dogCount: 5,
            lastVisitedAt: '2020-01-01T12:00:00',
            lastRainAt: '2020-01-02T12:00:00',
          ),
        ),
      ),
    );
    expect(find.byType(DogFaceIcon), findsNWidgets(5));
    final fades = tester.widgetList<Opacity>(
      find.descendant(
        of: find.byType(MarkingDogChart),
        matching: find.byType(Opacity),
      ),
    );
    expect(fades.length, 5);
    expect(fades.every((widget) => widget.opacity == 0.35), isTrue);
  });
  for (final count in [0, 1, 30]) {
    testWidgets('$count마리 표시와 작은 화면 줄바꿈', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 280, child: MarkingDogChart(dogCount: count)),
          ),
        ),
      );
      expect(find.byType(Container), findsNothing);
      expect(find.byType(DogFaceIcon), findsNWidgets(count > 12 ? 12 : count));
      if (count == 30) expect(find.text('+18마리'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
