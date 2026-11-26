import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../data/models/walk_model.dart';
import 'route_segments.dart';
import '../widgets/trace_affiliation.dart';

class DogTraceVisual {
  final String id;
  final String name;
  final String recency;
  final bool isToday;
  final int markerIndex;
  final int colorIndex;
  final List<NLatLng> points;
  final List<List<NLatLng>> segments;

  Color get color => otherTraceColor;

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
