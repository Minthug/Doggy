import 'package:flutter/material.dart';
import 'dog_face_icon.dart';
import 'marking_scent_notice.dart';

class MarkingDogChart extends StatelessWidget {
  final int dogCount;
  final String? lastVisitedAt;
  final String? lastRainAt;
  const MarkingDogChart({
    super.key,
    required this.dogCount,
    this.lastVisitedAt,
    this.lastRainAt,
  });

  @override
  Widget build(BuildContext context) {
    final count = dogCount < 0 ? 0 : dogCount;
    final visible = count > 12 ? 12 : count;
    return Semantics(
      label: '인기 스팟에 마킹한 강아지 $count마리. 같은 강아지는 한 번만 계산합니다.',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < visible; i++)
              Opacity(
                opacity: markingScentOpacity(
                  lastVisitedAt: lastVisitedAt,
                  lastRainAt: lastRainAt,
                ),
                child: DogFaceIcon(variant: i),
              ),
            if (count > visible)
              Text(
                '+${count - visible}마리',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
