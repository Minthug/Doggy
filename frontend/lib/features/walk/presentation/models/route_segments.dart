import 'dart:convert';

import 'package:flutter_naver_map/flutter_naver_map.dart';

List<List<NLatLng>> parseRouteSegments(String? geoJson) {
  if (geoJson == null || geoJson.isEmpty) return const [];
  try {
    final decoded = jsonDecode(geoJson);
    if (decoded is! Map<String, dynamic>) return const [];
    final coordinates = decoded['coordinates'];
    if (coordinates is! List) return const [];
    final List<dynamic>? rawSegments = decoded['type'] == 'LineString'
        ? [coordinates]
        : decoded['type'] == 'MultiLineString'
        ? coordinates
        : null;
    if (rawSegments == null) return const [];
    return rawSegments
        .whereType<List>()
        .map((segment) {
          return segment
              .whereType<List>()
              .where((point) {
                return point.length >= 2 && point[0] is num && point[1] is num;
              })
              .map((point) {
                return NLatLng(
                  (point[1] as num).toDouble(),
                  (point[0] as num).toDouble(),
                );
              })
              .toList();
        })
        .where((segment) => segment.length >= 2)
        .toList();
  } catch (_) {
    return const [];
  }
}
