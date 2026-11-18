import 'dart:io';
import 'dart:convert';

import 'package:doggy/features/walk/data/local/walk_draft_store.dart';
import 'package:doggy/features/walk/data/models/walk_model.dart';
import 'package:doggy/features/walk/data/repositories/walk_repository.dart';
import 'package:doggy/features/walk/domain/providers/walk_active_provider.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CompletingRepository extends WalkRepository {
  _CompletingRepository() : super(Dio());

  List<Map<String, dynamic>>? uploadedPoints;

  @override
  Future<WalkDetail> complete({
    required int sessionId,
    required List<Map<String, dynamic>> points,
    required DateTime endedAt,
  }) async {
    uploadedPoints = points;
    return WalkDetail(
      id: sessionId,
      distanceMeters: 12,
      durationSeconds: 5,
      status: 'COMPLETED',
    );
  }
}

void main() {
  test('bundled SQLite supports encrypted walk storage', () async {
    final directory = await Directory.systemTemp.createTemp('doggy-walk-db-');
    addTearDown(() => directory.delete(recursive: true));
    final db = WalkDraftDatabase(
      NativeDatabase(
        File('${directory.path}/walk.sqlite'),
        setup: (rawDb) {
          expect(rawDb.select('PRAGMA cipher;'), isNotEmpty);
          rawDb.execute("PRAGMA key = 'local-test-key';");
        },
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').getSingle();
    await db.close();
    final bytes = await File('${directory.path}/walk.sqlite').readAsBytes();
    expect(
      ascii.decode(bytes.take(15).toList(), allowInvalid: true),
      isNot('SQLite format 3'),
    );
  });

  test(
    'Drift stores a walk for its account and removes it after upload',
    () async {
      final store = WalkDraftStore(WalkDraftDatabase(NativeDatabase.memory()));
      addTearDown(store.db.close);
      final startedAt = DateTime(2026, 11, 16, 12);
      await store.begin('user-a', 7, startedAt, '[]');
      await store.addPoint(
        'user-a',
        7,
        StoredWalkPoint(
          37.218,
          126.944,
          startedAt.add(const Duration(seconds: 5)),
          5,
          false,
        ),
      );

      final saved = await store.load('user-a');
      expect(saved?.sessionId, 7);
      expect(saved?.points, hasLength(1));
      expect(saved?.points.single.lat, 37.218);
      expect(await store.load('user-b'), isNull);

      final endedAt = startedAt.add(const Duration(minutes: 10));
      await store.markEnding('user-a', endedAt);
      expect((await store.load('user-a'))?.endedAt, endedAt);
      await store.remove('user-a');
      expect(await store.load('user-a'), isNull);
    },
  );

  test('a restarted walk restores only for the same account', () async {
    final store = WalkDraftStore(WalkDraftDatabase(NativeDatabase.memory()));
    addTearDown(store.db.close);
    final startedAt = DateTime(2026, 11, 16, 12);
    await store.begin('user-a', 7, startedAt, '[]');
    await store.addPoint(
      'user-a',
      7,
      StoredWalkPoint(
        37.218,
        126.944,
        startedAt.add(const Duration(seconds: 5)),
        5,
        false,
      ),
    );

    ProviderContainer containerFor(String userKey) => ProviderContainer(
      overrides: [
        walkRepositoryProvider.overrideWithValue(WalkRepository(Dio())),
        walkDraftUserKeyProvider.overrideWith((ref) async => userKey),
        walkDraftStoreProvider.overrideWith((ref) async => store),
      ],
    );

    final accountA = containerFor('user-a');
    addTearDown(accountA.dispose);
    accountA.read(walkActiveProvider.notifier);
    for (
      var i = 0;
      i < 20 && !accountA.read(walkActiveProvider).isRecovered;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final restored = accountA.read(walkActiveProvider);
    expect(restored.isRecovered, isTrue);
    expect(restored.status, WalkStatus.paused);
    expect(restored.points, hasLength(1));

    final accountB = containerFor('user-b');
    addTearDown(accountB.dispose);
    accountB.read(walkActiveProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(accountB.read(walkActiveProvider).status, WalkStatus.idle);
  });

  test(
    'recovered points upload and are removed after server success',
    () async {
      final store = WalkDraftStore(WalkDraftDatabase(NativeDatabase.memory()));
      addTearDown(store.db.close);
      final startedAt = DateTime(2026, 11, 16, 12);
      await store.begin('user-a', 8, startedAt, '[]');
      await store.addPoint(
        'user-a',
        8,
        StoredWalkPoint(
          37.218,
          126.944,
          startedAt.add(const Duration(seconds: 5)),
          5,
          false,
        ),
      );
      final repository = _CompletingRepository();
      final container = ProviderContainer(
        overrides: [
          walkRepositoryProvider.overrideWithValue(repository),
          walkDraftUserKeyProvider.overrideWith((ref) async => 'user-a'),
          walkDraftStoreProvider.overrideWith((ref) async => store),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(walkActiveProvider.notifier);
      for (
        var i = 0;
        i < 20 && !container.read(walkActiveProvider).isRecovered;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(container.read(walkActiveProvider).isRecovered, isTrue);
      await notifier.completeWalk();
      expect(repository.uploadedPoints, hasLength(1));
      expect(await store.load('user-a'), isNull);
    },
  );
}
