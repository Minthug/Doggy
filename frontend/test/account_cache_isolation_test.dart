import 'dart:convert';

import 'package:doggy/core/storage/local_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String tokenFor(String userId) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': userId})));
  return 'header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached household and dogs are isolated between accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final householdA = LocalCache.userKey('my_household', tokenFor('1'))!;
    final dogsA = LocalCache.userKey('my_dogs', tokenFor('1'))!;
    final householdB = LocalCache.userKey('my_household', tokenFor('2'))!;
    final dogsB = LocalCache.userKey('my_dogs', tokenFor('2'))!;

    await LocalCache.write(householdA, {'name': 'A family'});
    await LocalCache.write(dogsA, [
      {'name': 'A dog'},
    ]);

    expect(await LocalCache.read(householdB), isNull);
    expect(await LocalCache.read(dogsB), isNull);

    // An old in-flight request can only write back into its captured A key.
    await LocalCache.write(householdA, {'name': 'A updated family'});
    expect(await LocalCache.read(householdB), isNull);
  });

  test('missing or malformed access token has no cache namespace', () {
    expect(LocalCache.userKey('my_dogs', null), isNull);
    expect(LocalCache.userKey('my_dogs', 'invalid'), isNull);
    expect(LocalCache.userKey('my_dogs', tokenFor('../1')), isNull);
  });
}
