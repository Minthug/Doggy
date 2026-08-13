import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/api/api_config.dart';
import 'core/app/app_metadata.dart';
import 'core/app/app_version_check.dart';
import 'core/naver_map_init.dart';
import 'core/storage/device_id_storage.dart';
import 'core/storage/token_storage.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/signup_screen.dart';
import 'features/home/presentation/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('[Firebase init error] $e');
  }
  // initNaverMap은 네트워크 검증을 하므로 runApp을 막지 않게 비동기로 실행
  initNaverMap().catchError((e) => debugPrint('[NaverMap init error] $e'));
  runApp(const ProviderScope(child: DoggyApp()));
}

class DoggyApp extends StatefulWidget {
  const DoggyApp({super.key});

  @override
  State<DoggyApp> createState() => _DoggyAppState();
}

final navigatorKey = GlobalKey<NavigatorState>();

class _DoggyAppState extends State<DoggyApp> {
  final _appLinks = AppLinks();

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
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        try {
          final response = await Dio().post<Map<String, dynamic>>(
            '${validatedApiBaseUrl()}/api/auth/oauth2/exchange',
            data: {'code': code},
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'X-Device-Id': await DeviceIdStorage.getOrCreateDeviceId(),
                ...AppMetadata.headers(),
              },
            ),
          );
          final data = response.data!;
          await TokenStorage.saveTokens(
            accessToken: data['accessToken'] as String,
            refreshToken: data['refreshToken'] as String,
          );
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/home',
            (_) => false,
          );
        } catch (e) {
          debugPrint('[OAuth exchange error] $e');
          await TokenStorage.clear();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Doggy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/home': (_) => const MainScreen(),
      },
      home: const _AuthGate(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF4CAF50),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🐶', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text(
              'Doggy',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '반려견 산책 기록',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
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
  AppVersionStatus? _versionStatus;

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    final versionStatus = await AppVersionCheckClient().check();
    final token = await TokenStorage.getAccessToken();
    if (mounted) {
      setState(() {
        _versionStatus = versionStatus;
        _isLoggedIn = token != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null || _versionStatus == null) {
      return const _SplashScreen();
    }
    if (_versionStatus!.updateRequired) {
      return _UpdateRequiredScreen(status: _versionStatus!);
    }
    return _isLoggedIn! ? const MainScreen() : const LoginScreen();
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  final AppVersionStatus status;

  const _UpdateRequiredScreen({required this.status});

  Future<void> _openStore() async {
    final url = Uri.tryParse(status.storeUrl);
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStoreUrl = status.storeUrl.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.system_update,
                size: 56,
                color: Color(0xFF4CAF50),
              ),
              const SizedBox(height: 24),
              Text(
                status.message.isNotEmpty ? status.message : '앱 업데이트가 필요합니다',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '현재 버전에서는 일부 기능을 사용할 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: hasStoreUrl ? _openStore : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('업데이트'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
