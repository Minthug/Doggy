import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/walk/presentation/widgets/trace_affiliation.dart';

void main() {
  test('viewer family flags are read from the API', () {
    final spot = PopularMarkingSpot.fromJson({
      'id': 1,
      'lat': 37.0,
      'lng': 127.0,
      'dogCount': 2,
      'familyVisited': true,
    });
    final visit = MarkingSpotVisit.fromJson({
      'id': 1,
      'familyDog': true,
      'dog': {'id': 2, 'name': '보리'},
    });
    expect(spot.familyVisited, isTrue);
    expect(visit.familyDog, isTrue);
    expect(
      MarkingSpotVisit.fromJson({
        'id': 2,
        'dog': {'id': 3, 'name': '두부'},
      }).familyDog,
      isFalse,
    );
  });

  testWidgets('family and others have distinct colors and labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TraceAffiliationBadge(isFamily: true),
              TraceAffiliationBadge(isFamily: false),
              TraceAffiliationBadge(isFamily: true, isSpot: true),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('우리 가족')).style!.color,
      familyTraceColor,
    );
    expect(
      tester.widget<Text>(find.text('다른 강아지')).style!.color,
      otherTraceColor,
    );
    expect(familyTraceColor, isNot(otherTraceColor));
    expect(find.text('가족도 방문'), findsOneWidget);
  });
}
