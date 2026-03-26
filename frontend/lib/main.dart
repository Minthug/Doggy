import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/naver_map_init.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/home/presentation/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNaverMap();
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
    );
  }
}
