import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doggy/core/api/api_client.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/walk/domain/providers/walk_provider.dart';

void main() {
  for (final failed in [
    <int>{},
    {2},
    {1, 2},
  ]) {
    test(
      'shared walk meets preserve successful sessions when $failed fail',
      () async {
        final requests = <String>[];
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options.path);
              final id = int.parse(options.path.split('/')[3]);
              if (failed.contains(id)) {
                handler.reject(DioException(requestOptions: options));
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: [
                      {
                        'metAt': DateTime.now().toIso8601String(),
                        'user': {'id': id + 100, 'nickname': '만난 보호자$id'},
                        'dogs': [
                          {'id': id, 'name': '만난 강아지$id'},
                        ],
                      },
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
            walkHistoryProvider.overrideWith(
              (ref) async => [
                for (final id in [1, 2])
                  WalkSession(
                    id: id,
                    startedAt: DateTime.now().toIso8601String(),
                    distanceMeters: 1000,
                    durationSeconds: 900,
                    status: 'COMPLETED',
                  ),
              ],
            ),
          ],
        );
        addTearDown(container.dispose);
        final result = await container.read(todayMeetsProvider.future);
        expect(result.failedSessionCount, failed.length);
        expect(
          result.meets.map((m) => m.dogs.single.id),
          [1, 2].where((id) => !failed.contains(id)).toList(),
        );
        expect(
          requests,
          containsAll(['/api/walks/1/meets', '/api/walks/2/meets']),
        );
      },
    );
  }
}
