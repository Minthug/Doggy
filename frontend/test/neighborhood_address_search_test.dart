import 'package:dio/dio.dart';
import 'package:doggy/core/api/api_client.dart';
import 'package:doggy/features/home/data/models/user_profile_model.dart';
import 'package:doggy/features/home/domain/providers/home_provider.dart';
import 'package:doggy/features/home/presentation/screens/neighborhood_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('주소 검색 결과의 좌표를 저장하고 입력 변경 시 선택을 해제한다', (tester) async {
    Map<String, dynamic>? saved;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'PUT') {
            saved = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(Response(requestOptions: options, data: {}));
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                data: [
                  {'address': '테스트시 테스트로 123', 'lat': 37.5, 'lng': 127.0},
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
          userProfileProvider.overrideWith(
            (ref) async => UserProfile(id: 1, nickname: '테스트'),
          ),
        ],
        child: MaterialApp(
          home: NeighborhoodSetupScreen(
            profile: UserProfile(id: 1, nickname: '테스트'),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '테스트로 123');
    await tester.tap(find.text('주소 검색'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('테스트시 테스트로 123'));
    await tester.pump();
    await tester.tap(find.text('이 주소로 내 동네 설정'));
    await tester.pumpAndSettle();
    expect(saved?['lat'], 37.5);
    expect(saved?['lng'], 127.0);
    await tester.enterText(find.byType(TextField), '다른 주소');
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '이 주소로 내 동네 설정'),
    );
    expect(button.onPressed, isNull);
  });
}
