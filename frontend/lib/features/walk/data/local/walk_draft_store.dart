import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/storage/local_cache.dart';

final walkDraftUserKeyProvider = FutureProvider<String?>(
  (ref) => LocalCache.currentUserKey('walk_draft'),
);

final walkDraftStoreProvider = FutureProvider<WalkDraftStore>((ref) async {
  final store = await WalkDraftStore.open();
  ref.onDispose(() => store.db.close());
  return store;
});

class StoredWalkPoint {
  final double lat;
  final double lng;
  final DateTime recordedAt;
  final double? accuracy;
  final bool segmentStart;

  const StoredWalkPoint(
    this.lat,
    this.lng,
    this.recordedAt,
    this.accuracy,
    this.segmentStart,
  );
}

class StoredWalkDraft {
  final int sessionId;
  final DateTime startedAt;
  final String dogsJson;
  final DateTime? endedAt;
  final List<StoredWalkPoint> points;

  const StoredWalkDraft(
    this.sessionId,
    this.startedAt,
    this.dogsJson,
    this.endedAt,
    this.points,
  );
}

class WalkDraftDatabase extends GeneratedDatabase {
  WalkDraftDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''
      CREATE TABLE walk_drafts (
        user_key TEXT PRIMARY KEY,
        session_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        dogs_json TEXT NOT NULL,
        ended_at TEXT
      )
    ''');
      await customStatement('''
      CREATE TABLE walk_draft_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_key TEXT NOT NULL,
        session_id INTEGER NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        recorded_at TEXT NOT NULL,
        accuracy REAL,
        segment_start INTEGER NOT NULL,
        FOREIGN KEY (user_key) REFERENCES walk_drafts(user_key) ON DELETE CASCADE
      )
    ''');
    },
  );
}

class WalkDraftStore {
  static const _keyName = 'doggy_walk_database_key';
  final WalkDraftDatabase db;

  WalkDraftStore(this.db);

  static Future<WalkDraftStore> open() async {
    const secureStorage = FlutterSecureStorage();
    var key = await secureStorage.read(key: _keyName);
    if (key == null) {
      final random = Random.secure();
      key = List<int>.generate(
        32,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      await secureStorage.write(key: _keyName, value: key);
    }
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/doggy_walks.sqlite');
    final database = WalkDraftDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (rawDb) {
          if (rawDb.select('PRAGMA cipher;').isEmpty) {
            throw StateError('Encrypted SQLite is unavailable');
          }
          rawDb.execute("PRAGMA key = '$key';");
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    await database.customSelect('SELECT 1').getSingle();
    return WalkDraftStore(database);
  }

  Future<void> begin(
    String userKey,
    int sessionId,
    DateTime startedAt,
    String dogsJson,
  ) async {
    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM walk_draft_points WHERE user_key = ?',
        [userKey],
      );
      await db.customStatement(
        '''
        INSERT OR REPLACE INTO walk_drafts (user_key, session_id, started_at, dogs_json, ended_at)
        VALUES (?, ?, ?, ?, NULL)
      ''',
        [userKey, sessionId, startedAt.toIso8601String(), dogsJson],
      );
    });
  }

  Future<void> addPoint(String userKey, int sessionId, StoredWalkPoint point) =>
      db.customStatement(
        '''
        INSERT INTO walk_draft_points
          (user_key, session_id, lat, lng, recorded_at, accuracy, segment_start)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          userKey,
          sessionId,
          point.lat,
          point.lng,
          point.recordedAt.toIso8601String(),
          point.accuracy,
          point.segmentStart ? 1 : 0,
        ],
      );

  Future<void> markEnding(String userKey, DateTime endedAt) =>
      db.customStatement(
        'UPDATE walk_drafts SET ended_at = ? WHERE user_key = ?',
        [endedAt.toIso8601String(), userKey],
      );

  Future<void> clearEnding(String userKey) => db.customStatement(
    'UPDATE walk_drafts SET ended_at = NULL WHERE user_key = ?',
    [userKey],
  );

  Future<StoredWalkDraft?> load(String userKey) async {
    final drafts = await db
        .customSelect(
          'SELECT session_id, started_at, dogs_json, ended_at FROM walk_drafts WHERE user_key = ?',
          variables: [Variable.withString(userKey)],
        )
        .get();
    if (drafts.isEmpty) return null;
    final draft = drafts.single.data;
    final sessionId = draft['session_id'] as int;
    final rows = await db
        .customSelect(
          '''
      SELECT lat, lng, recorded_at, accuracy, segment_start
      FROM walk_draft_points WHERE user_key = ? AND session_id = ? ORDER BY id
    ''',
          variables: [
            Variable.withString(userKey),
            Variable.withInt(sessionId),
          ],
        )
        .get();
    return StoredWalkDraft(
      sessionId,
      DateTime.parse(draft['started_at'] as String),
      draft['dogs_json'] as String,
      draft['ended_at'] == null
          ? null
          : DateTime.parse(draft['ended_at'] as String),
      rows.map((row) {
        final point = row.data;
        return StoredWalkPoint(
          (point['lat'] as num).toDouble(),
          (point['lng'] as num).toDouble(),
          DateTime.parse(point['recorded_at'] as String),
          (point['accuracy'] as num?)?.toDouble(),
          point['segment_start'] == 1,
        );
      }).toList(),
    );
  }

  Future<void> remove(String userKey) async {
    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM walk_draft_points WHERE user_key = ?',
        [userKey],
      );
      await db.customStatement('DELETE FROM walk_drafts WHERE user_key = ?', [
        userKey,
      ]);
    });
  }
}
