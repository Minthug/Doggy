import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/home/presentation/screens/main_screen.dart';

void main() {
  runApp(const ProviderScope(child: DoggyApp()));
}

class DoggyApp extends StatelessWidget {
  const DoggyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doggy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      routes: {
        '/signup': (_) => const SignUpScreen(),
      },
      // TODO: 개발용 - 로그인 없이 바로 메인 화면
      home: const MainScreen(),
      // 로그인 기능 활성화 시 아래 주석 해제
      // home: Consumer(builder: (context, ref, _) {
      //   return ref.watch(isLoggedInProvider).when(
      //     data: (isLoggedIn) =>
      //         isLoggedIn ? const MainScreen() : const LoginScreen(),
      //     loading: () => const Scaffold(
      //       body: Center(child: CircularProgressIndicator()),
      //     ),
      //     error: (e, _) => const LoginScreen(),
      //   );
      // }),
    );
  }
}
