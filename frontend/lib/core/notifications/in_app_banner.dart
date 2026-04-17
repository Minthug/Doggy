import 'dart:async';
import 'package:flutter/material.dart';

class InAppBanner {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show({
    required OverlayState overlay,
    required String title,
    required String body,
    BannerType type = BannerType.general,
    Duration duration = const Duration(seconds: 4),
  }) {
    _dismiss();

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        title: title,
        body: body,
        type: type,
        onDismiss: () => _dismiss(),
      ),
    );

    _current = entry;
    overlay.insert(entry);

    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

enum BannerType { ping, reminder, weather, achievement, general }

class _BannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final BannerType type;
  final VoidCallback onDismiss;

  const _BannerWidget({
    required this.title,
    required this.body,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animatedDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final config = _BannerConfig.of(widget.type);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: _animatedDismiss,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -200) {
                _animatedDismiss();
              }
            },
            child: Container(
              margin: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 왼쪽 컬러 바
                      Container(width: 5, color: config.color),

                      // 아이콘
                      Container(
                        width: 56,
                        color: config.color.withValues(alpha: 0.08),
                        child: Center(
                          child: Text(
                            config.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),

                      // 텍스트
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // 앱 이름 태그
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: config.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Doggy',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: config.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.body,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF555555),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 닫기 버튼
                      GestureDetector(
                        onTap: _animatedDismiss,
                        child: Container(
                          width: 36,
                          color: Colors.transparent,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerConfig {
  final Color color;
  final String emoji;

  const _BannerConfig({required this.color, required this.emoji});

  static _BannerConfig of(BannerType type) {
    return switch (type) {
      BannerType.ping        => const _BannerConfig(color: Color(0xFF4CAF50), emoji: '🐾'),
      BannerType.reminder    => const _BannerConfig(color: Color(0xFFFF9800), emoji: '🐕'),
      BannerType.weather     => const _BannerConfig(color: Color(0xFF2196F3), emoji: '🌤️'),
      BannerType.achievement => const _BannerConfig(color: Color(0xFFFFB300), emoji: '🎉'),
      BannerType.general     => const _BannerConfig(color: Color(0xFF4CAF50), emoji: '🐶'),
    };
  }
}
