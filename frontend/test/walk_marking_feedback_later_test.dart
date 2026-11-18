import 'package:dio/dio.dart';
import 'package:doggy/features/home/data/models/user_profile_model.dart';
import 'package:doggy/features/home/domain/providers/home_provider.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/walk/data/repositories/walk_repository.dart';
import 'package:doggy/features/walk/presentation/screens/walk_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWalkRepository extends WalkRepository {
  final int ownerId;
  bool answered = false;
  int candidateLoads = 0;
  Map<String, bool>? savedAnswers;
  List<int>? savedDogIds;

  _FakeWalkRepository({required this.ownerId}) : super(Dio());

  @override
  Future<WalkDetail> getDetail(int sessionId) async => WalkDetail.fromJson({
    'id': sessionId,
    'ownerId': ownerId,
    'distanceMeters': 1000,
    'durationSeconds': 300,
    'status': 'COMPLETED',
    'routeGeoJson': '{"type":"LineString","coordinates":[[126.944,37.218],[126.945,37.219]]}',
    'tracePathData': 'v1|0,0;100,100',
    'dogs': [
      {'id': 3, 'name': '보리'},
    ],
  });

  @override
  Future<List<MarkingSpotCandidate>> getMarkingCandidates(int sessionId) async {
    candidateLoads++;
    return answered
        ? []
        : const [
            MarkingSpotCandidate(
              candidateKey: 'a',
              lat: 37.218,
              lng: 126.944,
              detectedAt: '2026-11-12T12:01:00',
              dwellSeconds: 15,
              nearbyVisitCount: 0,
            ),
            MarkingSpotCandidate(
              candidateKey: 'b',
              lat: 37.219,
              lng: 126.945,
              detectedAt: '2026-11-12T12:02:00',
              dwellSeconds: 20,
              nearbyVisitCount: 0,
            ),
          ];
  }

  @override
  Future<void> submitMarkingFeedback({
    required int sessionId,
    required Map<String, bool> answers,
    required List<int> dogIds,
  }) async {
    savedAnswers = Map.of(answers);
    savedDogIds = List.of(dogIds);
    answered = true;
  }

  @override
  Future<List<WalkMeet>> getMeets(int sessionId) async => [];

  @override
  Future<List<WalkTraceDiscovery>> getTraceDiscoveries(int sessionId) async =>
      [];
}

Widget _screen(_FakeWalkRepository repository) => ProviderScope(
  overrides: [
    walkRepositoryProvider.overrideWithValue(repository),
    userProfileProvider.overrideWith(
      (ref) async => UserProfile(id: 7, nickname: '보호자'),
    ),
  ],
  child: const MaterialApp(
    home: WalkDetailScreen(
      sessionId: 1,
      markingCandidatesMap: ColoredBox(color: Colors.green),
    ),
  ),
);

void main() {
  testWidgets('나중에 산책 상세에서 답변하고 저장하면 확인 버튼이 사라진다', (tester) async {
    final repository = _FakeWalkRepository(ownerId: 7);
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();

    final open = find.text('마킹 후보 2곳 확인하기');
    expect(open, findsOneWidget);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(find.text('마킹한 곳이 있나요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '했어요').first);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('12:02 무렵'),
      120,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '아니에요').last);
    await tester.pump();
    await tester.tap(find.text('확인 저장'));
    await tester.pumpAndSettle();

    expect(repository.savedAnswers, {'a': true, 'b': false});
    expect(repository.savedDogIds, [3]);
    expect(find.text('마킹 후보 2곳 확인하기'), findsNothing);
    expect(find.text('빠진 마킹 위치 추가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('후보가 없어도 본인 산책에서 빠진 마킹 위치를 추가할 수 있다', (tester) async {
    final repository = _FakeWalkRepository(ownerId: 7)..answered = true;
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();

    expect(find.text('빠진 마킹 위치 추가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다른 가구 보호자의 산책에는 확인 버튼이 없다', (tester) async {
    final repository = _FakeWalkRepository(ownerId: 8);
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('마킹 후보'), findsNothing);
    expect(repository.candidateLoads, 0);
    expect(tester.takeException(), isNull);
  });
}
