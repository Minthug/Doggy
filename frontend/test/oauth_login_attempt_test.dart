import 'dart:convert';

import 'package:doggy/features/auth/data/oauth_login_attempt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('only the matching callback can consume the login attempt', () async {
    final challenge = await OAuthLoginAttempt.begin();
    expect(challenge, hasLength(43));
    expect(await OAuthLoginAttempt.takeVerifier('a' * 43), isNull);

    final verifier = await OAuthLoginAttempt.takeVerifier(challenge);
    expect(verifier, isNotNull);
    expect(OAuthLoginAttempt.challengeFor(verifier!), challenge);
    expect(await OAuthLoginAttempt.takeVerifier(challenge), isNull);
  });

  test('a new login attempt invalidates the previous callback', () async {
    final oldChallenge = await OAuthLoginAttempt.begin();
    final newChallenge = await OAuthLoginAttempt.begin();

    expect(await OAuthLoginAttempt.takeVerifier(oldChallenge), isNull);
    expect(await OAuthLoginAttempt.takeVerifier(newChallenge), isNotNull);
  });

  test('an expired login attempt cannot exchange a code', () async {
    final verifier = 'a' * 43;
    FlutterSecureStorage.setMockInitialValues({
      'pending_oauth_login': jsonEncode({
        'verifier': verifier,
        'createdAt': DateTime.now()
            .subtract(const Duration(minutes: 11))
            .millisecondsSinceEpoch,
      }),
    });

    expect(
      await OAuthLoginAttempt.takeVerifier(
        OAuthLoginAttempt.challengeFor(verifier),
      ),
      isNull,
    );
  });
}
