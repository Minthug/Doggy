import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../dog/data/models/dog_model.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';

// 산책 상태
enum WalkStatus { idle, inProgress, paused, completed }

class WalkState {
  final WalkStatus status;
  final WalkSession? session;
  final List<WalkPoint> points;
  final int elapsedSeconds;
  final double distanceMeters;
  final Position? currentPosition;
  final Dog? selectedDog;

  const WalkState({
    this.status = WalkStatus.idle,
    this.session,
    this.points = const [],
    this.elapsedSeconds = 0,
    this.distanceMeters = 0,
    this.currentPosition,
    this.selectedDog,
  });

  WalkState copyWith({
    WalkStatus? status,
    WalkSession? session,
    List<WalkPoint>? points,
    int? elapsedSeconds,
    double? distanceMeters,
    Position? currentPosition,
    Dog? selectedDog,
  }) =>
      WalkState(
        status: status ?? this.status,
        session: session ?? this.session,
        points: points ?? this.points,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        currentPosition: currentPosition ?? this.currentPosition,
        selectedDog: selectedDog ?? this.selectedDog,
      );

  String get elapsedText {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)}km';
    }
    return '${distanceMeters.toStringAsFixed(0)}m';
  }
}

class WalkPoint {
  final double lat;
  final double lng;
  final DateTime recordedAt;

  WalkPoint({required this.lat, required this.lng, required this.recordedAt});

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'recordedAt': recordedAt.toIso8601String(),
      };
}

final walkActiveProvider =
    StateNotifierProvider<WalkActiveNotifier, WalkState>((ref) {
  return WalkActiveNotifier(ref.watch(walkRepositoryProvider));
});

class WalkActiveNotifier extends StateNotifier<WalkState> {
  final WalkRepository _repository;
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;

  WalkActiveNotifier(this._repository) : super(const WalkState());

  Future<void> startWalk({Dog? dog}) async {
    final session = await _repository.start();
    state = state.copyWith(
      status: WalkStatus.inProgress,
      session: session,
      points: [],
      elapsedSeconds: 0,
      distanceMeters: 0,
      selectedDog: dog,
    );
    _startTimer();
    _startTracking();
  }

  Future<void> pauseWalk() async {
    if (state.session == null) return;
    await _repository.pause(state.session!.id);
    state = state.copyWith(status: WalkStatus.paused);
    _timer?.cancel();
    _positionSubscription?.pause();
  }

  Future<void> resumeWalk() async {
    if (state.session == null) return;
    await _repository.resume(state.session!.id);
    state = state.copyWith(status: WalkStatus.inProgress);
    _startTimer();
    _positionSubscription?.resume();
  }

  Future<void> completeWalk() async {
    if (state.session == null) return;
    _timer?.cancel();
    _positionSubscription?.cancel();

    await _repository.complete(
      sessionId: state.session!.id,
      points: state.points.map((p) => p.toJson()).toList(),
    );

    state = state.copyWith(status: WalkStatus.completed);
  }

  void resetWalk() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    state = const WalkState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  Future<void> _startTracking() async {
    _positionSubscription?.cancel();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // 5m 이상 이동 시 업데이트
      ),
    ).listen((position) {
      final newPoint = WalkPoint(
        lat: position.latitude,
        lng: position.longitude,
        recordedAt: DateTime.now(),
      );

      double addedDistance = 0;
      if (state.points.isNotEmpty) {
        final last = state.points.last;
        addedDistance = Geolocator.distanceBetween(
          last.lat,
          last.lng,
          position.latitude,
          position.longitude,
        );
      }

      state = state.copyWith(
        points: [...state.points, newPoint],
        distanceMeters: state.distanceMeters + addedDistance,
        currentPosition: position,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
