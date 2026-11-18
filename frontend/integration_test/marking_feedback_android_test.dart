import 'package:dio/dio.dart';
import 'package:doggy/core/naver_map_init.dart';
import 'package:doggy/features/home/data/models/user_profile_model.dart';
import 'package:doggy/features/home/domain/providers/home_provider.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/walk/data/repositories/walk_repository.dart';
import 'package:doggy/features/walk/presentation/screens/walk_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:integration_test/integration_test.dart';

class _DummyWalkRepository extends WalkRepository {
  final int candidateCount;
  bool answered = false;
  Map<String, bool>? savedAnswers;
  List<int>? savedDogIds;

  _DummyWalkRepository({this.candidateCount = 1}) : super(Dio());

  @override
  Future<WalkDetail> getDetail(int sessionId) async => WalkDetail.fromJson({
    'id': sessionId,
    'ownerId': 7,
    'distanceMeters': 480,
    'durationSeconds': 300,
    'status': 'COMPLETED',
    'dogs': [
      {'id': 3, 'name': '보리'},
    ],
  });

  @override
  Future<List<MarkingSpotCandidate>> getMarkingCandidates(
    int sessionId,
  ) async => answered
      ? []
      : List.generate(
          candidateCount,
          (index) => MarkingSpotCandidate(
            candidateKey: 'android-dummy-${index + 1}',
            lat: 37.218 + index * 0.001,
            lng: 126.944 + index * 0.001,
            detectedAt: '2026-11-12T12:0${index + 1}:00',
            dwellSeconds: 15,
            nearbyVisitCount: 0,
          ),
        );

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initNaverMap);

  testWidgets('Android: 건너뛴 마킹 후보를 다시 열어 저장한다', (tester) async {
    final repository = _DummyWalkRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walkRepositoryProvider.overrideWithValue(repository),
          userProfileProvider.overrideWith(
            (ref) async => UserProfile(id: 7, nickname: '보호자'),
          ),
        ],
        child: const MaterialApp(home: WalkDetailScreen(sessionId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    final open = find.text('마킹 후보 1곳 확인하기');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('마킹한 곳이 있나요?'), findsOneWidget);
    expect(find.byType(NaverMap), findsNWidgets(2));
    await tester.tap(find.text('지도에서 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이번에는 건너뛰기'));
    await tester.pumpAndSettle();

    expect(open, findsOneWidget);
    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '했어요'));
    await tester.pump();
    await tester.tap(find.text('확인 저장'));
    await tester.pumpAndSettle();

    expect(repository.savedAnswers, {'android-dummy-1': true});
    expect(repository.savedDogIds, [3]);
    expect(open, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final count in [2, 3]) {
    testWidgets('Android: 후보 $count곳의 마지막 장소까지 답변을 저장한다', (tester) async {
      final repository = _DummyWalkRepository(candidateCount: count);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walkRepositoryProvider.overrideWithValue(repository),
            userProfileProvider.overrideWith(
              (ref) async => UserProfile(id: 7, nickname: '보호자'),
            ),
          ],
          child: const MaterialApp(home: WalkDetailScreen(sessionId: 1)),
        ),
      );
      await tester.pumpAndSettle();

      final open = find.text('마킹 후보 $count곳 확인하기');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(NaverMap), findsNWidgets(2));

      for (var index = 0; index < count; index++) {
        final time = find.textContaining('12:0${index + 1} 무렵');
        await tester.scrollUntilVisible(
          time,
          120,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        final tile = find.ancestor(of: time, matching: find.byType(Row)).first;
        await tester.tap(
          find.descendant(of: tile, matching: find.text('지도에서 보기')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: tile,
            matching: find.widgetWithText(ChoiceChip, '아니에요'),
          ),
        );
        await tester.pump();
      }

      await tester.tap(find.text('확인 저장'));
      await tester.pumpAndSettle();
      expect(repository.savedAnswers, {
        for (var index = 1; index <= count; index++)
          'android-dummy-$index': false,
      });
      expect(repository.savedDogIds, [3]);
      expect(open, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
