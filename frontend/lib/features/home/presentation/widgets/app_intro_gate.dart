import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../walk/presentation/widgets/dog_face_icon.dart';

class AppIntroGate extends StatefulWidget {
  final int userId;
  final Widget child;
  final VoidCallback? onReady;
  const AppIntroGate({
    super.key,
    required this.userId,
    required this.child,
    this.onReady,
  });

  @override
  State<AppIntroGate> createState() => _AppIntroGateState();
}

class _AppIntroGateState extends State<AppIntroGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
  }

  Future<void> _showIfNeeded() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    if (!mounted) return;
    final key = 'app_intro_v1_${widget.userId}';
    if (prefs?.getBool(key) != true) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AppIntroDialog(),
      );
      if (confirmed == true) {
        try {
          await prefs?.setBool(key, true);
        } catch (_) {}
      }
    }
    if (mounted) widget.onReady?.call();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppIntroDialog extends StatelessWidget {
  const AppIntroDialog({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Doggy, 이렇게 사용해요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: DogFaceIcon(variant: 2, size: 64)),
                      SizedBox(height: 16),
                      _IntroItem(
                        icon: Icons.home_outlined,
                        title: '홈 · 오늘의 산책을 준비해요',
                        text:
                            '날씨와 산책 지수를 확인하고, 반려견 정보와 오늘의 산책 기록을 한눈에 볼 수 있어요.',
                      ),
                      SizedBox(height: 16),
                      _IntroItem(
                        icon: Icons.map_outlined,
                        title: '지도 · 산책하고 흔적을 찾아요',
                        text:
                            '산책 탭에서 기록을 시작하고, 마친 뒤 걸어온 경로를 확인해요. 마킹 여부는 나중에 답해도 돼요. 흔적 지도에서는 집 주변 2km의 인기 마킹 스팟을 볼 수 있어요.',
                      ),
                      SizedBox(height: 12),
                      Text(
                        '흔적은 시간이 흐르거나 비가 오면 옅게 표시해요.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DogFaceIcon(variant: 1, size: 28),
                          SizedBox(width: 12),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 12),
                          Opacity(
                            opacity: 0.65,
                            child: DogFaceIcon(variant: 1, size: 28),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 12),
                          Opacity(
                            opacity: 0.35,
                            child: DogFaceIcon(variant: 1, size: 28),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '강아지 수는 마킹 기록이에요. 실제 냄새가 남아 있는지는 알 수 없어요.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      SizedBox(height: 16),
                      _IntroItem(
                        icon: Icons.people_outline,
                        title: '커뮤니티 · 보호자들과 나눠요',
                        text: '다른 보호자들의 글과 사진을 둘러보고, 반려견의 일상과 산책 이야기를 나눠보세요.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('알겠어요, 시작할게요'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _IntroItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _IntroItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFF4CAF50), size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    ],
  );
}
