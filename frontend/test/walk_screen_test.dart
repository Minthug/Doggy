import 'package:dio/dio.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/walk/data/repositories/walk_repository.dart';
import 'package:doggy/features/walk/domain/providers/walk_active_provider.dart';
import 'package:doggy/features/walk/domain/providers/walk_provider.dart';
import 'package:doggy/features/walk/presentation/screens/walk_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _WalkNotifier extends WalkActiveNotifier {
  int retryCalls = 0;

  _WalkNotifier(super.repository, super.ref, WalkState initial) {
    state = initial;
  }

  @override
  Future<void> pauseWalk() async {
    state = state.copyWith(status: WalkStatus.paused);
  }

  @override
  Future<void> resumeWalk() async {
    state = state.copyWith(
      status: WalkStatus.inProgress,
      locationTrackingStatus: LocationTrackingStatus.tracking,
    );
  }

  @override
  Future<WalkDetail?> completeWalk() async {
    state = state.copyWith(status: WalkStatus.completed);
    return WalkDetail(
      id: state.session?.id ?? 1,
      distanceMeters: state.distanceMeters.round(),
      durationSeconds: state.elapsedSeconds,
      status: 'COMPLETED',
    );
  }

  @override
  Future<void> retryLocationTracking() async {
    retryCalls++;
  }

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

Widget _screen(WalkState state) => ProviderScope(
  overrides: [
    walkActiveProvider.overrideWith(
      (ref) => _WalkNotifier(WalkRepository(Dio()), ref, state),
    ),
  ],
  child: const MaterialApp(home: WalkScreen()),
);

void main() {
  testWidgets('산책 준비 화면에서 시작과 기록 진입을 제공한다', (tester) async {
    await tester.pumpWidget(_screen(const WalkState()));
    expect(find.text('산책 시작'), findsOneWidget);
    expect(find.text('산책 기록'), findsOneWidget);
    expect(find.text('산책 종료'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기록 중 일시정지와 재개 후에도 시간과 거리를 유지한다', (tester) async {
    await tester.pumpWidget(
      _screen(
        const WalkState(
          status: WalkStatus.inProgress,
          elapsedSeconds: 125,
          distanceMeters: 230,
        ),
      ),
    );
    expect(find.text('02:05'), findsOneWidget);
    expect(find.text('230m'), findsOneWidget);
    await tester.ensureVisible(find.text('일시정지'));
    await tester.tap(find.text('일시정지'));
    await tester.pumpAndSettle();
    expect(find.text('잠시 쉬어가고 있어요'), findsOneWidget);
    await tester.ensureVisible(find.text('계속 걷기'));
    await tester.tap(find.text('계속 걷기'));
    await tester.pumpAndSettle();
    expect(find.text('함께 걷는 시간을 기록해요'), findsOneWidget);
    expect(find.text('02:05'), findsOneWidget);
    expect(find.text('230m'), findsOneWidget);
    expect(find.text('산책 종료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면에서도 산책 종료 버튼까지 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _screen(const WalkState(status: WalkStatus.paused)),
    );
    await tester.ensureVisible(find.text('산책 종료'));
    expect(find.text('산책 종료').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('위치 신호 시간 초과 시 재시도와 위치 설정을 안내한다', (tester) async {
    late _WalkNotifier notifier;
    final state = WalkState(
      status: WalkStatus.inProgress,
      session: WalkSession(
        id: 1,
        distanceMeters: 0,
        durationSeconds: 0,
        status: 'IN_PROGRESS',
      ),
      locationTrackingStatus: LocationTrackingStatus.timedOut,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walkActiveProvider.overrideWith((ref) {
            notifier = _WalkNotifier(WalkRepository(Dio()), ref, state);
            return notifier;
          }),
        ],
        child: const MaterialApp(home: WalkScreen()),
      ),
    );

    expect(find.textContaining('위치 신호를 받지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('위치 설정'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(notifier.retryCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('산책 완료 후 월간 통계를 즉시 다시 조회한다', (tester) async {
    var monthlyLoads = 0;
    final initial = WalkState(
      status: WalkStatus.paused,
      session: WalkSession(
        id: 1,
        distanceMeters: 100,
        durationSeconds: 300,
        status: 'PAUSED',
      ),
      elapsedSeconds: 300,
      distanceMeters: 100,
    );
    final container = ProviderContainer(
      overrides: [
        walkActiveProvider.overrideWith(
          (ref) => _WalkNotifier(WalkRepository(Dio()), ref, initial),
        ),
        monthlyWalkStatsProvider.overrideWith((ref) async {
          monthlyLoads++;
          return MonthlyWalkStats(
            totalDistanceMeters: 100,
            totalDurationSeconds: 300,
            walkCount: monthlyLoads,
            month: DateTime.now().month,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final monthlySubscription = container.listen(
      monthlyWalkStatsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(monthlySubscription.close);
    await container.read(monthlyWalkStatsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WalkScreen()),
      ),
    );
    await tester.ensureVisible(find.text('산책 종료'));
    await tester.tap(find.text('산책 종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();
    await container.read(monthlyWalkStatsProvider.future);

    expect(monthlyLoads, 2);
    expect(tester.takeException(), isNull);
  });
}
