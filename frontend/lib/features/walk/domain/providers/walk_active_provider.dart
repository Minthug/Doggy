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
  final bool isSimulating;

  const WalkState({
    this.status = WalkStatus.idle,
    this.session,
    this.points = const [],
    this.elapsedSeconds = 0,
    this.distanceMeters = 0,
    this.currentPosition,
    this.selectedDog,
    this.isSimulating = false,
  });

  WalkState copyWith({
    WalkStatus? status,
    WalkSession? session,
    List<WalkPoint>? points,
    int? elapsedSeconds,
    double? distanceMeters,
    Position? currentPosition,
    Dog? selectedDog,
    bool? isSimulating,
  }) =>
      WalkState(
        status: status ?? this.status,
        session: session ?? this.session,
        points: points ?? this.points,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        currentPosition: currentPosition ?? this.currentPosition,
        selectedDog: selectedDog ?? this.selectedDog,
        isSimulating: isSimulating ?? this.isSimulating,
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
  Timer? _simTimer;
  StreamSubscription<Position>? _positionSubscription;
  int _simIndex = 0;

  // 기본 위치(37.218392, 126.944858) 기준 루프 경로
  static const _simRoute = <({double lat, double lng})>[
    (lat: 37.218392, lng: 126.944858),
    (lat: 37.218600, lng: 126.945100),
    (lat: 37.218800, lng: 126.945350),
    (lat: 37.219000, lng: 126.945600),
    (lat: 37.219200, lng: 126.945850),
    (lat: 37.219350, lng: 126.946150),
    (lat: 37.219400, lng: 126.946500),
    (lat: 37.219380, lng: 126.946850),
    (lat: 37.219300, lng: 126.947150),
    (lat: 37.219100, lng: 126.947350),
    (lat: 37.218850, lng: 126.947450),
    (lat: 37.218600, lng: 126.947400),
    (lat: 37.218350, lng: 126.947300),
    (lat: 37.218100, lng: 126.947100),
    (lat: 37.217900, lng: 126.946850),
    (lat: 37.217750, lng: 126.946550),
    (lat: 37.217700, lng: 126.946200),
    (lat: 37.217750, lng: 126.945850),
    (lat: 37.217850, lng: 126.945500),
    (lat: 37.218000, lng: 126.945200),
    (lat: 37.218100, lng: 126.944950),
    (lat: 37.218200, lng: 126.944870),
    (lat: 37.218280, lng: 126.944858),
    (lat: 37.218392, lng: 126.944858),
  ];

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
      isSimulating: false,
    );
    _startTimer();
    _startTracking();
  }

  Future<void> startSimulatedWalk({Dog? dog}) async {
    final session = await _repository.start();
    _simIndex = 0;
    state = state.copyWith(
      status: WalkStatus.inProgress,
      session: session,
      points: [],
      elapsedSeconds: 0,
      distanceMeters: 0,
      selectedDog: dog,
      isSimulating: true,
    );
    _startTimer();
    _startSimulation();
  }

  void _startSimulation() {
    _simTimer?.cancel();
    // 3초마다 다음 좌표로 이동 (빠른 테스트용)
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_simIndex >= _simRoute.length) {
        _simTimer?.cancel();
        return;
      }
      final coord = _simRoute[_simIndex++];
      _applyPosition(coord.lat, coord.lng);
    });
    // 첫 좌표 즉시 적용
    _applyPosition(_simRoute[0].lat, _simRoute[0].lng);
    _simIndex = 1;
  }

  void _applyPosition(double lat, double lng) {
    final newPoint = WalkPoint(
      lat: lat,
      lng: lng,
      recordedAt: DateTime.now(),
    );

    double addedDistance = 0;
    if (state.points.isNotEmpty) {
      final last = state.points.last;
      addedDistance = Geolocator.distanceBetween(
        last.lat, last.lng, lat, lng,
      );
    }

    final mockPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 15.0,
      heading: 0.0,
      speed: 1.4,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
      isMocked: true,
    );

    state = state.copyWith(
      points: [...state.points, newPoint],
      distanceMeters: state.distanceMeters + addedDistance,
      currentPosition: mockPosition,
    );
  }

  Future<void> pauseWalk() async {
    if (state.session == null) return;
    await _repository.pause(state.session!.id);
    state = state.copyWith(status: WalkStatus.paused);
    _timer?.cancel();
    if (state.isSimulating) {
      _simTimer?.cancel();
    } else {
      _positionSubscription?.pause();
    }
  }

  Future<void> resumeWalk() async {
    if (state.session == null) return;
    await _repository.resume(state.session!.id);
    state = state.copyWith(status: WalkStatus.inProgress);
    _startTimer();
    if (state.isSimulating) {
      _startSimulation();
    } else {
      _positionSubscription?.resume();
    }
  }

  Future<void> completeWalk() async {
    if (state.session == null) return;
    _timer?.cancel();
    _simTimer?.cancel();
    _positionSubscription?.cancel();

    await _repository.complete(
      sessionId: state.session!.id,
      points: state.points.map((p) => p.toJson()).toList(),
    );

    state = state.copyWith(status: WalkStatus.completed);
  }

  void resetWalk() {
    _timer?.cancel();
    _simTimer?.cancel();
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

    final results = await Future.wait([
      Geolocator.isLocationServiceEnabled(),
      Geolocator.checkPermission(),
    ]);

    final serviceEnabled = results[0] as bool;
    if (!serviceEnabled) return;

    LocationPermission permission = results[1] as LocationPermission;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
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
    _simTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
