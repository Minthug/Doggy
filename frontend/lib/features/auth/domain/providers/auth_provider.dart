import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';

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

  AuthAction(this._ref);

  Future<void> login(String email, String password) async {
    final repo = _ref.read(authRepositoryProvider);
    final tokens = await repo.login(email: email, password: password);
    await repo.saveTokens(tokens);
    _ref.invalidate(isLoggedInProvider);
  }

  Future<void> signUp(String email, String password, String nickname,
      {String? phone, String? address, String? birthDate}) async {
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
    _ref.invalidate(isLoggedInProvider);
  }

  Future<void> logout() async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.logout();
    _ref.invalidate(isLoggedInProvider);
  }
}
