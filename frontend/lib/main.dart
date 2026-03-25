import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/domain/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: DoggyApp()));
}

class DoggyApp extends ConsumerWidget {
  const DoggyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedInAsync = ref.watch(isLoggedInProvider);

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
      home: isLoggedInAsync.when(
        data: (isLoggedIn) =>
            isLoggedIn ? const HomeScreen() : const LoginScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => const LoginScreen(),
      ),
    );
  }
}
