import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/oauth_login_attempt.dart';
import '../../../dog/domain/providers/dog_provider.dart';
import '../../../household/domain/providers/household_provider.dart';
import '../../../walk/domain/providers/walk_provider.dart';
import '../../../walk/domain/providers/walk_active_provider.dart';
import '../../../home/domain/providers/home_provider.dart';
import '../../../../main.dart' show navigatorKey;
import '../../../../core/notifications/fcm_service.dart';

// 로그인 상태
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  // 토큰 있으면 로그인된 것으로 판단
  return await repo.hasToken();
});

// 로그인/회원가입 액션
final authActionProvider = Provider<AuthAction>((ref) {
  return AuthAction(ref);
});

class AuthAction {
  final Ref _ref;
  Future<void>? _logoutInFlight;

  AuthAction(this._ref);

  Future<void> login(String email, String password) async {
    final repo = _ref.read(authRepositoryProvider);
    final tokens = await repo.login(email: email, password: password);
    await repo.saveTokens(tokens);
    await OAuthLoginAttempt.clear();
    _invalidateDataProviders();
    _ref.invalidate(isLoggedInProvider);
  }

  Future<void> signUp(
    String email,
    String password,
    String nickname, {
    String? phone,
    String? address,
    String? birthDate,
  }) async {
    final repo = _ref.read(authRepositoryProvider);
    final tokens = await repo.signUp(
      email: email,
      password: password,
      nickname: nickname,
      phone: phone,
      address: address,
      birthDate: birthDate,
    );
    await repo.saveTokens(tokens);
    await OAuthLoginAttempt.clear();
    _invalidateDataProviders();
    _ref.invalidate(isLoggedInProvider);
  }

  Future<void> logout() => _logoutInFlight ??= _performLogout();

  Future<void> _performLogout() async {
    final repo = _ref.read(authRepositoryProvider);
    try {
      try {
        await OAuthLoginAttempt.clear();
      } catch (_) {}
      try {
        await _ref.read(fcmServiceProvider).unregisterToken();
      } catch (_) {
        // 서버 연결 실패 시에도 일반 로그아웃과 로컬 토큰 삭제는 진행한다.
      }
      await repo.logout();
    } finally {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
      );
      _invalidateDataProviders();
      _ref.invalidate(isLoggedInProvider);
      _logoutInFlight = null;
    }
  }

  void _invalidateDataProviders() {
    _ref.invalidate(userProfileProvider);
    _ref.invalidate(myDogsProvider);
    _ref.invalidate(myHouseholdProvider);
    _ref.invalidate(todayWalkStatsProvider);
    _ref.invalidate(walkIndexProvider);
    _ref.invalidate(walkHistoryProvider);
    _ref.invalidate(walkActiveProvider);
    _ref.invalidate(monthlyWalkStatsProvider);
  }
}
