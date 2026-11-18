import 'dart:io';

import 'package:doggy/features/walk/data/local/walk_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('encrypted walk draft survives reopening on Android', (
    tester,
  ) async {
    final startedAt = DateTime.now();
    final first = await WalkDraftStore.open();
    await first.begin('integration-test', 999999, startedAt, '[]');
    await first.addPoint(
      'integration-test',
      999999,
      StoredWalkPoint(
        37.218,
        126.944,
        startedAt.add(const Duration(seconds: 5)),
        5,
        false,
      ),
    );
    await first.db.close();

    final directory = await getApplicationSupportDirectory();
    final header = await File(
      '${directory.path}/doggy_walks.sqlite',
    ).openRead(0, 16).first;
    expect(header, isNot('SQLite format 3\u0000'.codeUnits));

    final reopened = await WalkDraftStore.open();
    final saved = await reopened.load('integration-test');
    expect(saved?.sessionId, 999999);
    expect(saved?.points, hasLength(1));
    await reopened.remove('integration-test');
    await reopened.db.close();
  });
}
