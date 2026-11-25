import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/features/walk/presentation/widgets/marking_dog_chart.dart';
import 'package:doggy/features/walk/presentation/widgets/dog_face_icon.dart';

void main() {
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
