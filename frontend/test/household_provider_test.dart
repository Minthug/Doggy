import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doggy/core/api/api_client.dart';
import 'package:doggy/core/storage/local_cache.dart';
import 'package:doggy/features/household/domain/providers/household_provider.dart';

const _cached = {
  'id': 1,
  'name': '기존 가족',
  'inviteCode': 'ABCD1234',
  'members': <Map<String, dynamic>>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': '999'})));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storage,
          (call) async =>
              call.method == 'read' ? 'header.$payload.signature' : null,
        );
    SharedPreferences.setMockInitialValues({
      'cache_999_my_household': jsonEncode(_cached),
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  for (final status in [200, 404, 500, null]) {
    testWidgets('cached family refreshes once with response $status', (
      tester,
    ) async {
      var requests = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            requests++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            final response = Response(
              requestOptions: options,
              statusCode: status,
              data: {..._cached, 'name': '갱신된 가족'},
            );
            if (status == 200) {
              handler.resolve(response);
            } else {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: status == null ? null : response,
                  type: status == null
                      ? DioExceptionType.connectionError
                      : DioExceptionType.badResponse,
                ),
              );
            }
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      final names = <String?>[];
      container.listen(myHouseholdProvider, (_, next) {
        if (next.hasValue) names.add(next.valueOrNull?.name);
      });
      addTearDown(container.dispose);

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(names, contains('기존 가족'));
      expect(requests, 1);
      final cached = await LocalCache.read('999_my_household');
      final family = container.read(myHouseholdProvider).valueOrNull;
      if (status == 200) {
        expect(family?.name, '갱신된 가족');
        expect(cached['name'], '갱신된 가족');
        // Explicit refresh still works without restarting a request loop.
        container.invalidate(myHouseholdProvider);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(requests, 2);
      } else if (status == 404) {
        expect(family, isNull);
        expect(cached, isNull);
      } else {
        expect(family?.name, '기존 가족');
        expect(cached['name'], '기존 가족');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposed refresh does not replace cached family', (
    tester,
  ) async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          handler.resolve(
            Response(
              requestOptions: options,
              data: {..._cached, 'name': '늦은 응답'},
            ),
          );
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    container.listen(myHouseholdProvider, (_, _) {});
    await tester.pump(const Duration(milliseconds: 20));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 200));
    expect((await LocalCache.read('999_my_household'))['name'], '기존 가족');
    expect(tester.takeException(), isNull);
  });
}
