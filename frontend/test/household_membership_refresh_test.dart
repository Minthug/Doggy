import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doggy/core/api/api_client.dart';
import 'package:doggy/core/providers/household_change_provider.dart';
import 'package:doggy/core/storage/local_cache.dart';
import 'package:doggy/features/dog/domain/providers/dog_provider.dart';
import 'package:doggy/features/household/domain/providers/household_provider.dart';
import 'package:doggy/features/household/presentation/screens/household_screen.dart';
import 'package:doggy/features/walk/domain/providers/walk_provider.dart';

const _family = {
  'id': 7,
  'name': '공유 가족',
  'inviteCode': 'ABCDEFGHIJKLMNOPQRST',
  'members': [
    {'userId': 1, 'nickname': '보호자', 'role': 'MEMBER'},
  ],
};

void main() {
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '1'})));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storage,
          (call) async =>
              call.method == 'read' ? 'header.$payload.signature' : null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null),
  );

  testWidgets('cached readers wait until old caches have been cleared', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cache_1_my_household': jsonEncode(_family),
      'cache_1_my_dogs': jsonEncode([
        {'id': 2, 'name': '이전 가족 반려견'},
      ]),
    });
    final ready = Completer<void>();
    var requests = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          if (options.path == '/api/households/me') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 404),
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                data: [
                  {'id': 1, 'name': '내 반려견'},
                ],
              ),
            );
          }
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        householdChangeProvider.overrideWith((ref) => ready.future),
      ],
    );
    addTearDown(container.dispose);
    container.listen(myHouseholdProvider, (_, _) {});
    container.listen(myDogsProvider, (_, _) {});
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests, 0);
    expect(container.read(myHouseholdProvider).isLoading, isTrue);
    expect(container.read(myDogsProvider).isLoading, isTrue);
    await Future.wait([clearHouseholdCache(), clearDogsCache()]);
    ready.complete();
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(container.read(myHouseholdProvider).requireValue, isNull);
    expect(container.read(myDogsProvider).requireValue.single.id, 1);
  });

  for (final scenario in [
    'create',
    'join',
    'leave',
    'leave-retry',
    'join-failed',
  ]) {
    testWidgets('$scenario refreshes family, dogs, walks, stats and encounters', (
      tester,
    ) async {
      var member = scenario.startsWith('leave');
      var failReads = false;
      final late = Completer<void>();
      final calls = <String, int>{};
      List<Map<String, dynamic>> dogs(bool shared) => [
        {'id': 1, 'name': '내 반려견'},
        if (shared) {'id': 2, 'name': '가족 반려견'},
      ];
      SharedPreferences.setMockInitialValues({
        'cache_1_my_dogs': jsonEncode(dogs(member)),
        if (member) 'cache_1_my_household': jsonEncode(_family),
      });
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final path = options.path;
            final key = '${options.method} $path';
            calls[key] = (calls[key] ?? 0) + 1;
            void fail(int status) => handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: status),
                type: DioExceptionType.badResponse,
              ),
            );
            if (options.method != 'GET') {
              if (scenario == 'join-failed') {
                fail(400);
                return;
              }
              member = options.method != 'DELETE';
              failReads = scenario == 'leave-retry';
              handler.resolve(Response(requestOptions: options, data: _family));
              return;
            }
            // Capture a response made before leave; deliver it after the new data.
            final shared = member;
            if (scenario.startsWith('leave') &&
                calls[key] == 1 &&
                (path == '/api/dogs' || path == '/api/households/me')) {
              await late.future;
            }
            if (failReads) {
              fail(500);
              return;
            }
            dynamic data;
            if (path == '/api/households/me') {
              if (!shared) {
                fail(404);
                return;
              }
              data = _family;
            } else if (path == '/api/dogs') {
              data = dogs(shared);
            } else if (path == '/api/walks') {
              data = [
                {
                  'id': shared ? 2 : 1,
                  'status': 'COMPLETED',
                  'startedAt': DateTime.now().toIso8601String(),
                  'durationSeconds': 600,
                  'dogs': [
                    {'id': shared ? 2 : 1, 'name': '반려견'},
                  ],
                },
              ];
            } else if (path.contains('/stats/')) {
              data = {'walkCount': shared ? 2 : 1};
            } else if (path.endsWith('/meets')) {
              data = [
                {
                  'user': {'id': shared ? 2 : 1, 'nickname': '만난 보호자'},
                  'dogs': [],
                },
              ];
            } else if (path.endsWith('/traces')) {
              data = [];
            } else {
              data = {'id': shared ? 2 : 1, 'status': 'COMPLETED'};
            }
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      for (final provider in <ProviderListenable<dynamic>>[
        myDogsProvider,
        walkHistoryProvider,
        todayWalkStatsProvider,
        monthlyWalkStatsProvider,
        todayMeetsProvider,
        todayDogCaloriesProvider,
        latestTodayWalkDetailProvider,
        latestTodayWalkTraceDiscoveriesProvider,
      ]) {
        container.listen(provider, (_, _) {});
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HouseholdScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final before = member ? 2 : 1;
      expect(
        container.read(todayWalkStatsProvider).requireValue.walkCount,
        before,
      );
      expect(container.read(myDogsProvider).requireValue.length, before);

      if (scenario.startsWith('leave')) {
        await tester.tap(find.text('가구 탈퇴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('탈퇴').last);
      } else {
        await tester.tap(
          find.text(scenario == 'create' ? '가구 만들기' : '초대 코드로 참여'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          scenario == 'create' ? '새 가족' : 'ABCDEFGHIJKLMNOPQRST',
        );
        await tester.tap(find.text(scenario == 'create' ? '만들기' : '참여').last);
      }
      await tester.pumpAndSettle();
      if (scenario == 'join-failed') {
        expect(find.text('유효하지 않은 초대 코드입니다'), findsOneWidget);
        expect(calls['GET /api/walks'], 1);
        expect(container.read(myDogsProvider).requireValue.length, 1);
        return;
      }
      if (scenario == 'leave-retry') {
        expect(find.text('가족 정보를 불러오지 못했어요.'), findsOneWidget);
        expect(find.text('공유 가족'), findsNothing);
        expect(container.read(myDogsProvider).hasError, isTrue);
        expect(container.read(myDogsProvider).valueOrNull, isEmpty);
        failReads = false;
        await tester.tap(find.text('다시 불러오기'));
        await tester.pumpAndSettle();
      }
      late.complete();
      await tester.pumpAndSettle();
      final after = member ? 2 : 1;
      expect(container.read(myDogsProvider).requireValue.length, after);
      expect(
        container.read(myHouseholdProvider).requireValue?.id,
        member ? 7 : null,
      );
      expect(container.read(walkHistoryProvider).requireValue.single.id, after);
      expect(
        container.read(todayWalkStatsProvider).requireValue.walkCount,
        after,
      );
      expect(
        container.read(monthlyWalkStatsProvider).requireValue.walkCount,
        after,
      );
      expect(
        container.read(todayMeetsProvider).requireValue.meets.single.user.id,
        after,
      );
      expect(container.read(todayDogCaloriesProvider).requireValue.keys, [
        after,
      ]);
      expect(
        container.read(latestTodayWalkDetailProvider).requireValue?.id,
        after,
      );
      expect(
        container.read(latestTodayWalkTraceDiscoveriesProvider).hasValue,
        isTrue,
      );
      expect((await LocalCache.read('1_my_dogs') as List).length, after);
      expect(
        await LocalCache.read('1_my_household'),
        member ? isNotNull : isNull,
      );
      expect(calls['GET /api/walks'], scenario == 'leave-retry' ? 3 : 2);
      expect(tester.takeException(), isNull);
    });
  }
}
