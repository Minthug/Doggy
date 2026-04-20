import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../dog/data/models/dog_model.dart';
import '../../data/models/walk_model.dart';
import '../../data/repositories/walk_repository.dart';

String _formatDateTime(DateTime dt) {
  final utc = dt.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}'
      '-${utc.month.toString().padLeft(2, '0')}'
      '-${utc.day.toString().padLeft(2, '0')}'
      'T${utc.hour.toString().padLeft(2, '0')}'
      ':${utc.minute.toString().padLeft(2, '0')}'
      ':${utc.second.toString().padLeft(2, '0')}';
}

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
        'recordedAt': _formatDateTime(recordedAt),
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
  Timer? _simPingTimer; // 시뮬레이션 전용 핑 타이머 (실제 GPS 없으므로 별도 유지)
  StreamSubscription<Position>? _positionSubscription;
  int _simIndex = 0;

  // wall-clock 기반 경과 시간
  DateTime? _walkStartedAt;
  int _pausedSeconds = 0;
  DateTime? _pausedAt;

  // 위치 스트림 기반 핑 — 마지막 서버 전송 시각
  DateTime? _lastPingAt;
  static const _pingIntervalSeconds = 10;

  // 시뮬레이션 경로 (봉담 기준)
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
    _walkStartedAt = DateTime.now();
    _pausedSeconds = 0;
    _pausedAt = null;
    _lastPingAt = null;
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
    _walkStartedAt = DateTime.now();
    _pausedSeconds = 0;
    _pausedAt = null;
    _lastPingAt = null;
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
    _startSimPingTimer();
  }

  void _startSimulation() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_simIndex >= _simRoute.length) {
        _simTimer?.cancel();
        return;
      }
      final coord = _simRoute[_simIndex++];
      _applyPosition(coord.lat, coord.lng);
    });
    _applyPosition(_simRoute[0].lat, _simRoute[0].lng);
    _simIndex = 1;
  }

  // 시뮬레이션 모드 전용: 실제 GPS가 없으니 타이머로 핑
  void _startSimPingTimer() {
    _simPingTimer?.cancel();
    _simPingTimer = Timer.periodic(const Duration(seconds: _pingIntervalSeconds), (_) {
      final pos = state.currentPosition;
      final session = state.session;
      if (pos == null || session == null) return;
      if (state.status != WalkStatus.inProgress) return;
      _repository
          .updateLocation(session.id, pos.latitude, pos.longitude)
          .catchError((e) { debugPrint('[핑] 위치 업데이트 실패: $e'); });
    });
  }

  void _applyPosition(double lat, double lng) {
    final newPoint = WalkPoint(lat: lat, lng: lng, recordedAt: DateTime.now());

    double addedDistance = 0;
    if (state.points.isNotEmpty) {
      final last = state.points.last;
      addedDistance = Geolocator.distanceBetween(last.lat, last.lng, lat, lng);
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
    _pausedAt = DateTime.now();
    state = state.copyWith(status: WalkStatus.paused);
    _timer?.cancel();
    _simPingTimer?.cancel();
    if (state.isSimulating) {
      _simTimer?.cancel();
    } else {
      _positionSubscription?.pause();
    }
  }

  Future<void> resumeWalk() async {
    if (state.session == null) return;
    await _repository.resume(state.session!.id);
    if (_pausedAt != null) {
      _pausedSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
    state = state.copyWith(status: WalkStatus.inProgress);
    _startTimer();
    if (state.isSimulating) {
      _startSimulation();
      _startSimPingTimer();
    } else {
      _positionSubscription?.resume();
    }
  }

  Future<void> completeWalk() async {
    if (state.session == null) return;
    _timer?.cancel();
    _simTimer?.cancel();
    _simPingTimer?.cancel();
    _positionSubscription?.cancel();

    await _repository.complete(
      sessionId: state.session!.id,
      points: state.points.map((p) => p.toJson()).toList(),
      endedAt: DateTime.now(),
    );

    state = state.copyWith(status: WalkStatus.completed);
  }

  static const stepLat = 0.00009;
  static const stepLng = 0.00011;

  void moveByKey(double dlat, double dlng) {
    if (state.status != WalkStatus.inProgress) return;
    final last = state.currentPosition;
    final lat = (last?.latitude ?? 37.218392) + dlat;
    final lng = (last?.longitude ?? 126.944858) + dlng;
    _applyPosition(lat, lng);
  }

  void resetWalk() {
    _timer?.cancel();
    _simTimer?.cancel();
    _simPingTimer?.cancel();
    _positionSubscription?.cancel();
    state = const WalkState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_walkStartedAt == null) return;
      final elapsed = DateTime.now().difference(_walkStartedAt!).inSeconds - _pausedSeconds;
      state = state.copyWith(elapsedSeconds: elapsed < 0 ? 0 : elapsed);
    });
  }

  Future<void> _startTracking() async {
    _positionSubscription?.cancel();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // iOS: "항상 허용"이 없으면 요청 (백그라운드 추적 안정성)
    if (Platform.isIOS && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
      debugPrint('[위치] iOS 권한 업그레이드 시도 → $permission');
    }

    final locationSettings = Platform.isIOS
        ? AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            activityType: ActivityType.fitness,
            allowBackgroundLocationUpdates: true,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          )
        : AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: '산책 중',
              notificationText: '경로를 기록하고 있습니다.',
              enableWakeLock: true,
            ),
          );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      // 포인트 기록 + 거리 계산
      final newPoint = WalkPoint(
        lat: position.latitude,
        lng: position.longitude,
        recordedAt: DateTime.now(),
      );

      double addedDistance = 0;
      if (state.points.isNotEmpty) {
        final last = state.points.last;
        addedDistance = Geolocator.distanceBetween(
          last.lat, last.lng, position.latitude, position.longitude,
        );
      }

      state = state.copyWith(
        points: [...state.points, newPoint],
        distanceMeters: state.distanceMeters + addedDistance,
        currentPosition: position,
      );

      // 위치 콜백에서 직접 서버 핑 — 백그라운드에서도 동작
      final session = state.session;
      if (session == null || state.status != WalkStatus.inProgress) return;

      final now = DateTime.now();
      if (_lastPingAt == null ||
          now.difference(_lastPingAt!).inSeconds >= _pingIntervalSeconds) {
        _lastPingAt = now;
        _repository
            .updateLocation(session.id, position.latitude, position.longitude)
            .catchError((e) { debugPrint('[핑] 위치 업데이트 실패: $e'); });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _simTimer?.cancel();
    _simPingTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
