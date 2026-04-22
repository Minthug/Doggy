import 'dart:async';
import 'package:flutter/material.dart';

class _BannerEvent {
  final String title;
  final String body;
  final BannerType type;
  const _BannerEvent({required this.title, required this.body, required this.type});
}

class InAppBanner {
  static final _controller = StreamController<_BannerEvent>.broadcast();

  static void emit({
    required String title,
    required String body,
    BannerType type = BannerType.general,
  }) {
    _controller.add(_BannerEvent(title: title, body: body, type: type));
  }
}

enum BannerType { ping, reminder, weather, achievement, general }

class BannerLayer extends StatefulWidget {
  const BannerLayer({super.key});

  @override
  State<BannerLayer> createState() => _BannerLayerState();
}

class _BannerLayerState extends State<BannerLayer> {
  _BannerEvent? _current;
  Timer? _timer;
  late final StreamSubscription<_BannerEvent> _sub;

  @override
  void initState() {
    super.initState();
    _sub = InAppBanner._controller.stream.listen(_onEvent);
  }

  void _onEvent(_BannerEvent event) {
    _timer?.cancel();
    setState(() => _current = event);
    _timer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _current = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _current;
    if (event == null) return const SizedBox.shrink();
    return _BannerWidget(
      key: ValueKey('${event.title}${event.body}'),
      title: event.title,
      body: event.body,
      type: event.type,
      onDismiss: _dismiss,
    );
  }
}

class _BannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final BannerType type;
  final VoidCallback onDismiss;

  const _BannerWidget({
    super.key,
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
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final config = _BannerConfig.of(widget.type);

    // Align 사용: Overlay 없이 Stack 내 최상단에서 동작
    return Align(
      alignment: Alignment.topCenter,
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
                      Container(width: 5, color: config.color),
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
