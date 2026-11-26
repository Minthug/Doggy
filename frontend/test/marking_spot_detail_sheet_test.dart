import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/core/api/api_client.dart';
import 'package:doggy/features/walk/presentation/widgets/marking_spot_detail_sheet.dart';

void main() {
  for (final fails in [false, true]) {
    testWidgets('popular spot opens detail (error=$fails)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            expect(options.path, '/api/walks/marking-spots/7');
            if (fails) {
              handler.reject(DioException(requestOptions: options));
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': 7,
                  'lat': 37.0,
                  'lng': 127.0,
                  'visitCount': 8,
                  'visits': List.generate(
                    8,
                    (i) => {
                      'id': i,
                      'familyDog': i == 0,
                      'dog': {'id': i, 'name': '강아지$i', 'breed': '푸들'},
                    },
                  ),
                },
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return TextButton(
                    onPressed: () => showMarkingSpotDetail(
                      context,
                      spotId: 7,
                      title: '내 동네 마킹 스팟 1위',
                    ),
                    child: const Text('스팟 열기'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('스팟 열기'));
      await tester.pumpAndSettle();
      expect(find.text('내 동네 마킹 스팟 1위'), findsOneWidget);
      if (fails) {
        expect(find.text('마킹 스팟 정보를 불러오지 못했습니다'), findsOneWidget);
      } else {
        expect(find.text('우리 가족'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('강아지7'),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('강아지7'), findsOneWidget);
      }
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
