import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/core/api/api_client.dart';
import 'package:doggy/features/home/data/models/user_profile_model.dart';
import 'package:doggy/features/home/domain/providers/home_provider.dart';
import 'package:doggy/features/dog/domain/providers/dog_provider.dart';
import 'package:doggy/features/dog/presentation/screens/dog_register_screen.dart';
import 'package:doggy/features/walk/domain/providers/walk_provider.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/profile/presentation/screens/profile_tab.dart';

void main() {
  testWidgets('프로필에서 주소 변경 후 돌아오고 반려견 등록을 열 수 있다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var profile = UserProfile(
      id: 7,
      nickname: '테스트',
      address: '테스트시 처음로 1',
      homeLat: 37.5,
      homeLng: 127,
    );
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'PUT') {
            profile = UserProfile(
              id: 7,
              nickname: '테스트',
              address: '테스트시 새집로 2',
              homeLat: 37.6,
              homeLng: 127.1,
            );
            handler.resolve(Response(requestOptions: options, data: {}));
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                data: [
                  {'address': '테스트시 새집로 2', 'lat': 37.6, 'lng': 127.1},
                ],
              ),
            );
          }
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          userProfileProvider.overrideWith((ref) async => profile),
          myDogsProvider.overrideWith((ref) async => []),
          monthlyWalkStatsProvider.overrideWith(
            (ref) async => MonthlyWalkStats(
              totalDistanceMeters: 0,
              totalDurationSeconds: 0,
              walkCount: 0,
              month: 11,
            ),
          ),
        ],
        child: const MaterialApp(home: ProfileTab()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.textContaining('테스트시 처음로 1'), findsOneWidget);
    await tester.ensureVisible(find.text('집주소 · 내 동네'));
    await tester.tap(find.text('집주소 · 내 동네'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '새집로 2');
    await tester.tap(find.text('주소 검색'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('테스트시 새집로 2'));
    await tester.pump();
    await tester.tap(find.text('이 주소로 내 동네 설정'));
    await tester.pumpAndSettle();
    expect(find.text('집주소 검색'), findsNothing);
    expect(find.textContaining('테스트시 새집로 2'), findsOneWidget);
    await tester.ensureVisible(find.text('반려견 등록'));
    await tester.tap(find.text('반려견 등록'));
    await tester.pumpAndSettle();
    expect(find.byType(DogRegisterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
