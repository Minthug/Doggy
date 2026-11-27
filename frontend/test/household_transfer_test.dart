import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doggy/core/api/api_client.dart';
import 'package:doggy/features/home/data/models/user_profile_model.dart';
import 'package:doggy/features/home/domain/providers/home_provider.dart';
import 'package:doggy/features/household/presentation/screens/household_screen.dart';
import 'package:doggy/features/household/domain/providers/household_provider.dart';

void main() {
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  for (final scenario in ['owner', 'member', 'rejected', 'new-owner']) {
    testWidgets('$scenario transfer controls and permission updates', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var ownerId = 1;
      var left = false;
      var transfers = 0;
      Map<String, dynamic> household() => {
        'id': 7,
        'name': '위임 테스트 가족',
        'inviteCode': 'ABCDEFGHIJKLMNOPQRST',
        'members': [
          for (final id in [1, 2])
            {
              'userId': id,
              'nickname': id == 1 ? '보호자A' : '보호자B',
              'role': ownerId == id ? 'OWNER' : 'MEMBER',
            },
        ],
      };
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/households/owner/transfer') {
              transfers++;
              if (scenario == 'rejected') {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 403,
                    ),
                  ),
                );
                return;
              }
              ownerId = options.data['targetUserId'] as int;
              handler.resolve(
                Response(requestOptions: options, data: household()),
              );
            } else if (options.path == '/api/households/leave') {
              left = true;
              handler.resolve(Response(requestOptions: options));
            } else if (options.path == '/api/households/me') {
              if (left) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 404,
                    ),
                  ),
                );
              } else {
                handler.resolve(
                  Response(requestOptions: options, data: household()),
                );
              }
            } else {
              handler.resolve(Response(requestOptions: options, data: []));
            }
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          userProfileProvider.overrideWith(
            (ref) async => UserProfile(
              id: (scenario == 'member' || scenario == 'new-owner') ? 2 : 1,
              nickname: '현재 보호자',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      if (scenario == 'new-owner') {
        container.listen(myHouseholdProvider, (_, _) {});
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(container.read(myHouseholdProvider).hasValue, isTrue);
        ownerId = 2;
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HouseholdScreen()),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario == 'new-owner') {
        expect(find.text('관리자 위임'), findsOneWidget);
        expect(find.text('코드 재발급'), findsOneWidget);
        expect(transfers, 0);
        return;
      }
      if (scenario == 'member') {
        expect(find.text('관리자 위임'), findsNothing);
        expect(find.text('코드 재발급'), findsNothing);
        return;
      }
      expect(find.text('코드 재발급'), findsOneWidget);
      await tester.ensureVisible(find.text('관리자 위임'));
      await tester.tap(find.text('관리자 위임'));
      await tester.pumpAndSettle();
      expect(find.textContaining('보호자B님에게'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(transfers, 0);
      await tester.tap(find.text('관리자 위임'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('위임하기'));
      await tester.pumpAndSettle();
      expect(transfers, 1);
      if (scenario == 'rejected') {
        expect(find.text('관리자 위임에 실패했습니다. 다시 시도해 주세요.'), findsOneWidget);
        expect(ownerId, 1);
        expect(find.text('관리자 위임'), findsOneWidget);
      } else {
        expect(ownerId, 2);
        expect(find.text('관리자 위임'), findsNothing);
        expect(find.text('코드 재발급'), findsNothing);
        await tester.ensureVisible(find.text('가구 탈퇴'));
        await tester.tap(find.text('가구 탈퇴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('탈퇴').last);
        await tester.pumpAndSettle();
        expect(left, isTrue);
        expect(find.text('아직 가구가 없어요'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
