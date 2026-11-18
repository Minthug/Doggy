import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../data/models/walk_model.dart';
import 'route_segments.dart';

const dogTracePalette = <Color>[
  Color(0xFFD8A07C),
  Color(0xFF87A9C4),
  Color(0xFFA897C0),
  Color(0xFF8FB097),
  Color(0xFFD39AA3),
  Color(0xFFD4BA78),
  Color(0xFF82B5B0),
  Color(0xFF929FC4),
  Color(0xFFCB8D7D),
  Color(0xFF93BCA5),
  Color(0xFFB38FA8),
  Color(0xFF789EA2),
];

class DogTraceVisual {
  final String id;
  final String name;
  final String recency;
  final bool isToday;
  final int markerIndex;
  final int colorIndex;
  final List<NLatLng> points;
  final List<List<NLatLng>> segments;

  Color get color => dogTracePalette[colorIndex % dogTracePalette.length];

  const DogTraceVisual({
    required this.id,
    required this.name,
    required this.recency,
    required this.isToday,
    required this.markerIndex,
    required this.colorIndex,
    required this.points,
    required this.segments,
  });
}

List<DogTraceVisual> buildDogTraceMapItems(
  List<WalkTraceDiscovery> discoveries,
) {
  return discoveries.expand((discovery) {
    final segments = parseRouteSegments(discovery.routeGeoJson);
    final points = segments.expand((segment) => segment).toList();
    if (points.length < 2) return const <DogTraceVisual>[];
    return discovery.dogs.map(
      (dog) => DogTraceVisual(
        id: '${discovery.sessionId}-${dog.id}',
        name: dog.name,
        recency: discovery.recencyText,
        isToday: discovery.isToday,
        markerIndex: points.length ~/ 2,
        colorIndex: dog.id,
        points: points,
        segments: segments,
      ),
    );
  }).toList();
}
