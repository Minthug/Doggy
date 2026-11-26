import 'package:flutter/material.dart';

const familyTraceColor = Color(0xFF388E3C);
const otherTraceColor = Color(0xFF1976D2);

class TraceAffiliationBadge extends StatelessWidget {
  final bool isFamily;
  final bool isSpot;
  const TraceAffiliationBadge({
    super.key,
    required this.isFamily,
    this.isSpot = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFamily ? familyTraceColor : otherTraceColor;
    return Text(
      isFamily ? (isSpot ? '가족도 방문' : '우리 가족') : '다른 강아지',
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }
}
