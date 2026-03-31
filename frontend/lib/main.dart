import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/naver_map_init.dart';
import 'core/notifications/fcm_service.dart';
import 'core/storage/token_storage.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/home/presentation/screens/main_screen.dart';
export 'features/home/presentation/screens/main_screen.dart' show mainScreenKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNaverMap();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: DoggyApp()));
}

class DoggyApp extends StatefulWidget {
  const DoggyApp({super.key});

  @override
  State<DoggyApp> createState() => _DoggyAppState();
}

class _DoggyAppState extends State<DoggyApp> {
  final _appLinks = AppLinks();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) => _handleDeepLink(uri));
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme == 'doggy' &&
        uri.host == 'auth' &&
        uri.path == '/callback') {
      final accessToken = uri.queryParameters['accessToken'];
      final refreshToken = uri.queryParameters['refreshToken'];
      if (accessToken != null && refreshToken != null) {
        await TokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        _navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/home', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Doggy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/home': (_) => MainScreen(key: mainScreenKey),
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final token = await TokenStorage.getAccessToken();
    if (mounted) setState(() => _isLoggedIn = token != null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isLoggedIn!
        ? MainScreen(key: mainScreenKey)
        : const LoginScreen();
  }
}
