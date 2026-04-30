import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../place/presentation/screens/map_tab.dart';
import '../../../walk/domain/providers/walk_active_provider.dart';
import '../../../walk/presentation/screens/walk_screen.dart';

class WalkPlaceTab extends ConsumerStatefulWidget {
  const WalkPlaceTab({super.key});

  @override
  ConsumerState<WalkPlaceTab> createState() => _WalkPlaceTabState();
}

class _WalkPlaceTabState extends ConsumerState<WalkPlaceTab> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final walkStatus = ref.watch(walkActiveProvider).status;
    final isWalking = walkStatus == WalkStatus.inProgress ||
        walkStatus == WalkStatus.paused;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [WalkScreen(), MapTab()],
          ),
          Positioned(
            top: topPadding + 8,
            left: 0,
            right: 0,
            child: Center(
              child: _SubTabSwitcher(
                index: _index,
                isWalking: isWalking,
                onChanged: (i) => setState(() => _index = i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubTabSwitcher extends StatelessWidget {
  final int index;
  final bool isWalking;
  final ValueChanged<int> onChanged;

  const _SubTabSwitcher({
    required this.index,
    required this.isWalking,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('🐾 산책', 0, showDot: isWalking && index != 0),
          const SizedBox(width: 4),
          _tab('📍 주변 장소', 1, showDot: false),
        ],
      ),
    );
  }

  Widget _tab(String label, int i, {required bool showDot}) {
    final selected = index == i;
    return GestureDetector(
      onTap: () => onChanged(i),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF4CAF50) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
          if (showDot)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
