import 'package:dio/dio.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/walk/data/repositories/walk_repository.dart';
import 'package:doggy/features/walk/data/local/walk_draft_store.dart';
import 'package:doggy/features/walk/domain/providers/walk_active_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingWalkRepository extends WalkRepository {
  _FailingWalkRepository() : super(Dio());

  int completeCalls = 0;

  @override
  Future<WalkSession> start({List<int> dogIds = const []}) async => WalkSession(
    id: 1,
    distanceMeters: 0,
    durationSeconds: 0,
    status: 'IN_PROGRESS',
  );

  @override
  Future<WalkSession> pause(int sessionId) async => WalkSession(
    id: sessionId,
    distanceMeters: 0,
    durationSeconds: 0,
    status: 'PAUSED',
  );

  @override
  Future<WalkSession> resume(int sessionId) async => WalkSession(
    id: sessionId,
    distanceMeters: 0,
    durationSeconds: 0,
    status: 'IN_PROGRESS',
  );

  @override
  Future<WalkDetail> complete({
    required int sessionId,
    required List<Map<String, dynamic>> points,
    required DateTime endedAt,
  }) async {
    completeCalls++;
    throw StateError('offline');
  }
}

void main() {
  test('재개 후 첫 위치는 새 구간으로 보내고 쉬는 중 이동은 더하지 않는다', () async {
    final repository = _FailingWalkRepository();
    final store = WalkDraftStore(WalkDraftDatabase(NativeDatabase.memory()));
    addTearDown(store.db.close);
    final container = ProviderContainer(
      overrides: [
        walkRepositoryProvider.overrideWithValue(repository),
        walkDraftUserKeyProvider.overrideWith((ref) async => 'test-user'),
        walkDraftStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(walkActiveProvider.notifier);

    await notifier.startSimulatedWalk();
    await notifier.pauseWalk();
    await notifier.resumeWalk();
    await Future<void>.delayed(const Duration(milliseconds: 3200));

    final state = container.read(walkActiveProvider);
    expect(state.points, hasLength(2));
    expect(state.points.last.segmentStart, isTrue);
    expect(state.points.last.toJson()['segmentStart'], isTrue);
    expect(state.distanceMeters, 0);
  });

  test('저장 재시도 3회가 모두 실패해도 산책 기록을 다시 이어간다', () async {
    final repository = _FailingWalkRepository();
    final store = WalkDraftStore(WalkDraftDatabase(NativeDatabase.memory()));
    addTearDown(store.db.close);
    final container = ProviderContainer(
      overrides: [
        walkRepositoryProvider.overrideWithValue(repository),
        walkDraftUserKeyProvider.overrideWith((ref) async => 'test-user'),
        walkDraftStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(walkActiveProvider.notifier);

    await notifier.startSimulatedWalk();
    expect(container.read(walkActiveProvider).points, hasLength(1));
    await expectLater(notifier.completeWalk(), throwsStateError);
    expect(repository.completeCalls, 3);
    expect(container.read(walkActiveProvider).status, WalkStatus.inProgress);
    expect((await store.load('test-user'))?.points, hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 3200));
    expect(container.read(walkActiveProvider).points, hasLength(2));
  });
}
