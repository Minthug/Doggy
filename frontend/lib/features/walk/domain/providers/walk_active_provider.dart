import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../dog/data/models/dog_model.dart';
import '../../data/models/walk_model.dart';
import '../../data/local/walk_draft_store.dart';
import '../../data/repositories/walk_repository.dart';
import 'walk_provider.dart';

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year.toString().padLeft(4, '0')}'
      '-${local.month.toString().padLeft(2, '0')}'
      '-${local.day.toString().padLeft(2, '0')}'
      'T${local.hour.toString().padLeft(2, '0')}'
      ':${local.minute.toString().padLeft(2, '0')}'
      ':${local.second.toString().padLeft(2, '0')}';
}

enum WalkStatus { idle, inProgress, paused, completed }

enum LocationTrackingStatus {
  idle,
  waiting,
  tracking,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timedOut,
  error,
}

class WalkState {
  final WalkStatus status;
  final WalkSession? session;
  final List<WalkPoint> points;
  final int elapsedSeconds;
  final double distanceMeters;
  final Position? currentPosition;
  final List<Dog> selectedDogs;
  final bool isSimulating;
  final List<MarkingSpotCandidate> markingSpotCandidates;
  final LocationTrackingStatus locationTrackingStatus;
  final bool isRecovered;
  final bool localSaveFailed;

  const WalkState({
    this.status = WalkStatus.idle,
    this.session,
    this.points = const [],
    this.elapsedSeconds = 0,
    this.distanceMeters = 0,
    this.currentPosition,
    this.selectedDogs = const [],
    this.isSimulating = false,
    this.markingSpotCandidates = const [],
    this.locationTrackingStatus = LocationTrackingStatus.idle,
    this.isRecovered = false,
    this.localSaveFailed = false,
  });

  WalkState copyWith({
    WalkStatus? status,
    WalkSession? session,
    List<WalkPoint>? points,
    int? elapsedSeconds,
    double? distanceMeters,
    Position? currentPosition,
    List<Dog>? selectedDogs,
    bool? isSimulating,
    List<MarkingSpotCandidate>? markingSpotCandidates,
    LocationTrackingStatus? locationTrackingStatus,
    bool? isRecovered,
    bool? localSaveFailed,
  }) => WalkState(
    status: status ?? this.status,
    session: session ?? this.session,
    points: points ?? this.points,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    currentPosition: currentPosition ?? this.currentPosition,
    selectedDogs: selectedDogs ?? this.selectedDogs,
    isSimulating: isSimulating ?? this.isSimulating,
    markingSpotCandidates: markingSpotCandidates ?? this.markingSpotCandidates,
    locationTrackingStatus:
        locationTrackingStatus ?? this.locationTrackingStatus,
    isRecovered: isRecovered ?? this.isRecovered,
    localSaveFailed: localSaveFailed ?? this.localSaveFailed,
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
  final double? accuracy;
  final bool segmentStart;

  WalkPoint({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.accuracy,
    this.segmentStart = false,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'recordedAt': _formatDateTime(recordedAt),
    if (accuracy != null) 'accuracy': accuracy,
    if (segmentStart) 'segmentStart': true,
  };
}

bool isFreshWalkPosition({
  required DateTime positionRecordedAt,
  required DateTime now,
  required WalkPoint? lastPoint,
}) {
  final positionAge = now.difference(positionRecordedAt);
  if (positionAge.isNegative || positionAge > const Duration(seconds: 10)) {
    return false;
  }
  return lastPoint == null || positionRecordedAt.isAfter(lastPoint.recordedAt);
}

bool shouldRecordStationaryFix({
  required WalkPoint lastPoint,
  required Position position,
  required DateTime now,
}) {
  if (!isFreshWalkPosition(
        positionRecordedAt: position.timestamp,
        now: now,
        lastPoint: lastPoint,
      ) ||
      !position.accuracy.isFinite ||
      position.accuracy < 0 ||
      position.accuracy > 40 ||
      now.difference(position.timestamp) > const Duration(seconds: 3) ||
      (position.speed.isFinite && position.speed > 0.8) ||
      position.timestamp.difference(lastPoint.recordedAt) <
          const Duration(seconds: 4)) {
    return false;
  }
  return Geolocator.distanceBetween(
        lastPoint.lat,
        lastPoint.lng,
        position.latitude,
        position.longitude,
      ) <=
      12;
}

bool shouldRecordWalkPosition({
  required WalkPoint? lastPoint,
  required double lat,
  required double lng,
  required double accuracy,
  required DateTime recordedAt,
  bool segmentStart = false,
}) {
  if (!accuracy.isFinite || accuracy < 0 || accuracy > 40) return false;
  if (lastPoint == null || segmentStart) return true;
  final seconds =
      recordedAt.difference(lastPoint.recordedAt).inMilliseconds / 1000;
  if (seconds <= 0) return false;
  final meters = Geolocator.distanceBetween(
    lastPoint.lat,
    lastPoint.lng,
    lat,
    lng,
  );
  if (meters / seconds > 12) return false;
  // Small changes inside the reported GPS uncertainty are usually drift.
  final uncertainty = ((lastPoint.accuracy ?? accuracy) + accuracy) / 2;
  return meters >= uncertainty.clamp(3.0, 10.0);
}

bool shouldRequestStationaryFix({
  required DateTime now,
  required DateTime? lastMovingFixAt,
  DateTime? lastStreamFixAt,
}) =>
    (lastStreamFixAt == null ||
        now.difference(lastStreamFixAt) >= const Duration(seconds: 5)) &&
    (lastMovingFixAt == null ||
        now.difference(lastMovingFixAt) >= const Duration(seconds: 8));

WalkPoint stationaryWalkPoint(WalkPoint lastPoint, Position fix) => WalkPoint(
  lat: lastPoint.lat,
  lng: lastPoint.lng,
  recordedAt: fix.timestamp,
  accuracy: lastPoint.accuracy,
);

final walkActiveProvider = StateNotifierProvider<WalkActiveNotifier, WalkState>(
  (ref) {
    return WalkActiveNotifier(ref.watch(walkRepositoryProvider), ref);
  },
);

class WalkActiveNotifier extends StateNotifier<WalkState> {
  final WalkRepository _repository;
  final Ref _ref;
  Timer? _timer;
  Timer? _simTimer;
  Timer? _simPingTimer; // 시뮬레이션 전용 핑 타이머 (실제 GPS 없으므로 별도 유지)
  Timer? _locationWaitTimer;
  Timer? _stationarySampleTimer;
  bool _stationarySampleInFlight = false;
  DateTime? _lastMovingFixAt;
  DateTime? _lastStreamFixAt;
  StreamSubscription<Position>? _positionSubscription;
  int _simIndex = 0;
  bool _nextPointStartsSegment = false;
  WalkDraftStore? _draftStore;
  String? _draftUserKey;
  DateTime? _recoveredEndedAt;
  Object? _restoreError;
  late final Future<void> _restoreFuture;
  Future<void> _pointWrites = Future.value();
  bool _completing = false;

  // wall-clock 기반 경과 시간
  DateTime? _walkStartedAt;
  int _pausedSeconds = 0;
  DateTime? _pausedAt;

  // 위치 스트림 기반 핑 — 마지막 서버 전송 시각
  DateTime? _lastPingAt;
  static const _pingIntervalSeconds = 10;
  static const _locationWaitTimeout = Duration(seconds: 15);
  static const _stationarySampleInterval = Duration(seconds: 5);

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

  WalkActiveNotifier(this._repository, this._ref) : super(const WalkState()) {
    _restoreFuture = _restoreWalk().catchError((Object error) {
      _restoreError = error;
      debugPrint('[산책] 로컬 기록 복구 실패: $error');
    });
  }

  Future<void> _restoreWalk() async {
    final userKey = await _ref.read(walkDraftUserKeyProvider.future);
    if (userKey == null) return;
    final store = await _ref.read(walkDraftStoreProvider.future);
    _draftStore = store;
    _draftUserKey = userKey;
    final saved = await store.load(userKey);
    if (saved == null || !mounted || state.status != WalkStatus.idle) return;

    final points = saved.points
        .map(
          (point) => WalkPoint(
            lat: point.lat,
            lng: point.lng,
            recordedAt: point.recordedAt,
            accuracy: point.accuracy,
            segmentStart: point.segmentStart,
          ),
        )
        .toList();
    double distance = 0;
    for (var i = 1; i < points.length; i++) {
      if (!points[i].segmentStart) {
        distance += Geolocator.distanceBetween(
          points[i - 1].lat,
          points[i - 1].lng,
          points[i].lat,
          points[i].lng,
        );
      }
    }
    final dogs = (jsonDecode(saved.dogsJson) as List<dynamic>)
        .map((value) => Dog.fromJson(value as Map<String, dynamic>))
        .toList();
    final lastTime =
        saved.endedAt ??
        (points.isEmpty ? saved.startedAt : points.last.recordedAt);
    _walkStartedAt = saved.startedAt;
    _recoveredEndedAt = lastTime;
    state = WalkState(
      status: WalkStatus.paused,
      session: WalkSession(
        id: saved.sessionId,
        startedAt: _formatDateTime(saved.startedAt),
        distanceMeters: 0,
        durationSeconds: 0,
        status: 'PAUSED',
      ),
      points: points,
      distanceMeters: distance,
      elapsedSeconds: lastTime
          .difference(saved.startedAt)
          .inSeconds
          .clamp(0, 2147483647),
      selectedDogs: dogs,
      isRecovered: true,
    );
  }

  Future<void> _beginDraft(WalkSession session, List<Dog> dogs) async {
    await _restoreFuture;
    if (_restoreError != null) throw StateError('산책 기록 저장소를 열지 못했습니다');
    final store = _draftStore;
    final userKey = _draftUserKey;
    if (store == null || userKey == null) throw StateError('로그인이 필요합니다');
    await store.begin(
      userKey,
      session.id,
      session.startedAtDate ?? DateTime.now(),
      jsonEncode(
        dogs
            .map(
              (dog) => {
                'id': dog.id,
                'name': dog.name,
                'breed': dog.breed,
                'weightKg': dog.weightKg,
                'isNeutered': dog.isNeutered,
              },
            )
            .toList(),
      ),
    );
  }

  void _persistPoint(WalkPoint point) {
    final store = _draftStore;
    final userKey = _draftUserKey;
    final sessionId = state.session?.id;
    if (store == null || userKey == null || sessionId == null) return;
    _pointWrites = _pointWrites
        .then(
          (_) => store.addPoint(
            userKey,
            sessionId,
            StoredWalkPoint(
              point.lat,
              point.lng,
              point.recordedAt,
              point.accuracy,
              point.segmentStart,
            ),
          ),
        )
        .catchError((Object error) {
          debugPrint('[산책] 로컬 좌표 저장 실패: $error');
          if (mounted) state = state.copyWith(localSaveFailed: true);
        });
  }

  Future<void> startWalk({List<Dog> dogs = const []}) async {
    await _restoreFuture;
    if (_restoreError != null || _draftStore == null || _draftUserKey == null) {
      throw StateError('산책 기록 저장소를 열지 못했습니다');
    }
    if (state.status != WalkStatus.idle &&
        state.status != WalkStatus.completed) {
      throw StateError('복구할 산책 기록이 있습니다');
    }
    final session = await _repository.start(
      dogIds: dogs.map((d) => d.id).toList(),
    );
    await _beginDraft(session, dogs);
    _walkStartedAt = DateTime.now();
    _pausedSeconds = 0;
    _pausedAt = null;
    _lastPingAt = null;
    _nextPointStartsSegment = false;
    _lastMovingFixAt = null;
    _lastStreamFixAt = null;
    state = state.copyWith(
      status: WalkStatus.inProgress,
      session: session,
      points: [],
      elapsedSeconds: 0,
      distanceMeters: 0,
      selectedDogs: dogs,
      isSimulating: false,
      locationTrackingStatus: LocationTrackingStatus.waiting,
      isRecovered: false,
      localSaveFailed: false,
    );
    _startTimer();
    _startTracking();
    _startStationarySampling();
  }

  Future<void> startSimulatedWalk({List<Dog> dogs = const []}) async {
    await _restoreFuture;
    if (_restoreError != null || _draftStore == null || _draftUserKey == null) {
      throw StateError('산책 기록 저장소를 열지 못했습니다');
    }
    if (state.status != WalkStatus.idle &&
        state.status != WalkStatus.completed) {
      throw StateError('복구할 산책 기록이 있습니다');
    }
    final session = await _repository.start(
      dogIds: dogs.map((d) => d.id).toList(),
    );
    await _beginDraft(session, dogs);
    _simIndex = 0;
    _walkStartedAt = DateTime.now();
    _pausedSeconds = 0;
    _pausedAt = null;
    _lastPingAt = null;
    _nextPointStartsSegment = false;
    _lastMovingFixAt = null;
    _lastStreamFixAt = null;
    state = state.copyWith(
      status: WalkStatus.inProgress,
      session: session,
      points: [],
      elapsedSeconds: 0,
      distanceMeters: 0,
      selectedDogs: dogs,
      isSimulating: true,
      locationTrackingStatus: LocationTrackingStatus.tracking,
      isRecovered: false,
      localSaveFailed: false,
    );
    _startTimer();
    _applyPosition(_simRoute[0].lat, _simRoute[0].lng);
    _simIndex = 1;
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
  }

  // 시뮬레이션 모드 전용: 실제 GPS가 없으니 타이머로 핑
  void _startSimPingTimer() {
    _simPingTimer?.cancel();
    _simPingTimer = Timer.periodic(
      const Duration(seconds: _pingIntervalSeconds),
      (_) {
        final pos = state.currentPosition;
        final session = state.session;
        if (pos == null || session == null) return;
        if (state.status != WalkStatus.inProgress) return;
        _repository
            .updateLocation(session.id, pos.latitude, pos.longitude)
            .catchError((e) {
              debugPrint('[핑] 위치 업데이트 실패: $e');
              _handlePingError(e);
            });
      },
    );
  }

  void _handlePingError(Object e) {
    if (e is DioException && e.response?.statusCode == 400) {
      _timer?.cancel();
      _simTimer?.cancel();
      _simPingTimer?.cancel();
      _positionSubscription?.cancel();
      state = state.copyWith(status: WalkStatus.completed);
    }
  }

  void _applyPosition(double lat, double lng) {
    final segmentStart = _nextPointStartsSegment;
    _nextPointStartsSegment = false;
    final newPoint = WalkPoint(
      lat: lat,
      lng: lng,
      recordedAt: DateTime.now(),
      accuracy: 5,
      segmentStart: segmentStart,
    );

    double addedDistance = 0;
    if (state.points.isNotEmpty && !segmentStart) {
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
    _persistPoint(newPoint);
  }

  Future<void> pauseWalk() async {
    if (state.session == null ||
        state.status != WalkStatus.inProgress ||
        state.isRecovered) {
      return;
    }
    await _repository.pause(state.session!.id);
    _pausedAt = DateTime.now();
    state = state.copyWith(status: WalkStatus.paused);
    _timer?.cancel();
    _simPingTimer?.cancel();
    _locationWaitTimer?.cancel();
    _stationarySampleTimer?.cancel();
    if (state.isSimulating) {
      _simTimer?.cancel();
    } else {
      _positionSubscription?.pause();
    }
  }

  Future<void> resumeWalk() async {
    if (state.session == null ||
        state.status != WalkStatus.paused ||
        state.isRecovered) {
      return;
    }
    await _repository.resume(state.session!.id);
    if (_pausedAt != null) {
      _pausedSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
    state = state.copyWith(status: WalkStatus.inProgress);
    _nextPointStartsSegment = true;
    _startTimer();
    if (state.isSimulating) {
      _startSimulation();
      _startSimPingTimer();
    } else {
      _startTracking();
      _startStationarySampling();
    }
  }

  Future<WalkDetail?> completeWalk() async {
    if (_completing) throw StateError('산책을 저장하는 중입니다');
    _completing = true;
    try {
      return await _completeWalk();
    } finally {
      _completing = false;
    }
  }

  Future<WalkDetail?> _completeWalk() async {
    if (state.session == null) return null;
    _timer?.cancel();
    _simTimer?.cancel();
    _simPingTimer?.cancel();
    _locationWaitTimer?.cancel();
    _stationarySampleTimer?.cancel();
    _positionSubscription?.cancel();

    await _pointWrites;
    final endedAt = _recoveredEndedAt ?? DateTime.now();
    final points = state.points.map((p) => p.toJson()).toList();
    final sessionId = state.session!.id;
    final store = _draftStore;
    final userKey = _draftUserKey;
    if (store != null && userKey != null) {
      try {
        await store.markEnding(userKey, endedAt);
      } catch (error) {
        debugPrint('[산책] 종료 시각 로컬 저장 실패: $error');
        state = state.copyWith(localSaveFailed: true);
      }
    }

    Object? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final detail = await _repository.complete(
          sessionId: sessionId,
          points: points,
          endedAt: endedAt,
        );
        if (store != null && userKey != null) {
          try {
            await store.remove(userKey);
          } catch (error) {
            debugPrint('[산책] 완료된 로컬 기록 삭제 실패: $error');
          }
        }
        _recoveredEndedAt = null;
        state = state.copyWith(
          status: WalkStatus.completed,
          markingSpotCandidates: [],
        );
        _ref.invalidate(walkHistoryProvider);
        return detail;
      } catch (e) {
        lastError = e;
        debugPrint('[산책완료] 저장 실패 (시도 ${attempt + 1}/3): $e');
        if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
      }
    }
    if (!state.isRecovered && store != null && userKey != null) {
      try {
        await store.clearEnding(userKey);
      } catch (error) {
        debugPrint('[산책] 종료 재시도 상태 저장 실패: $error');
      }
    }
    if (mounted &&
        state.status == WalkStatus.inProgress &&
        state.session?.id == sessionId) {
      _startTimer();
      if (state.isSimulating) {
        _startSimulation();
        _startSimPingTimer();
      } else {
        _startTracking();
        _startStationarySampling();
      }
    }
    throw lastError!;
  }

  Future<void> loadMarkingCandidates() async {
    final session = state.session;
    if (session == null || state.status != WalkStatus.completed) return;
    final candidates = await _repository.getMarkingCandidates(session.id);
    if (mounted && state.session?.id == session.id) {
      state = state.copyWith(markingSpotCandidates: candidates);
    }
  }

  Future<void> shareMarkingSpot(MarkingSpotCandidate candidate) async {
    final session = state.session;
    if (session == null) return;
    final dogIds = state.selectedDogs.map((dog) => dog.id).toList();
    if (dogIds.isEmpty) return;
    await _repository.shareMarkingSpot(
      sessionId: session.id,
      candidate: candidate,
      dogIds: dogIds,
    );
    state = state.copyWith(
      markingSpotCandidates: state.markingSpotCandidates
          .where((item) => item.candidateKey != candidate.candidateKey)
          .toList(),
    );
  }

  Future<void> submitMarkingFeedback(Map<String, bool> answers) async {
    final session = state.session;
    if (session == null) return;
    await _repository.submitMarkingFeedback(
      sessionId: session.id,
      answers: answers,
      dogIds: state.selectedDogs.map((dog) => dog.id).toList(),
    );
    state = state.copyWith(markingSpotCandidates: []);
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
    _locationWaitTimer?.cancel();
    _stationarySampleTimer?.cancel();
    _positionSubscription?.cancel();
    _nextPointStartsSegment = false;
    _lastMovingFixAt = null;
    _lastStreamFixAt = null;
    state = const WalkState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_walkStartedAt == null) return;
      final elapsed =
          DateTime.now().difference(_walkStartedAt!).inSeconds - _pausedSeconds;
      state = state.copyWith(elapsedSeconds: elapsed < 0 ? 0 : elapsed);
    });
  }

  void _startStationarySampling() {
    _stationarySampleTimer?.cancel();
    _stationarySampleTimer = Timer.periodic(_stationarySampleInterval, (
      _,
    ) async {
      if (state.status != WalkStatus.inProgress ||
          _completing ||
          state.isSimulating ||
          state.locationTrackingStatus != LocationTrackingStatus.tracking ||
          state.points.isEmpty ||
          _nextPointStartsSegment ||
          _stationarySampleInFlight ||
          !shouldRequestStationaryFix(
            now: DateTime.now(),
            lastMovingFixAt: _lastMovingFixAt,
            lastStreamFixAt: _lastStreamFixAt,
          )) {
        return;
      }
      final sessionId = state.session?.id;
      _stationarySampleInFlight = true;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        if (state.status == WalkStatus.inProgress &&
            !_completing &&
            state.session?.id == sessionId &&
            position.speed.isFinite &&
            position.speed > 0.8 &&
            position.accuracy.isFinite &&
            position.accuracy >= 0 &&
            position.accuracy <= 40 &&
            !DateTime.now().isBefore(position.timestamp) &&
            DateTime.now().difference(position.timestamp) <=
                const Duration(seconds: 3)) {
          _lastMovingFixAt = DateTime.now();
        }
        if (state.status != WalkStatus.inProgress ||
            _completing ||
            state.session?.id != sessionId ||
            _nextPointStartsSegment ||
            state.points.isEmpty ||
            !shouldRecordStationaryFix(
              lastPoint: state.points.last,
              position: position,
              now: DateTime.now(),
            )) {
          return;
        }
        state = state.copyWith(
          points: [
            ...state.points,
            stationaryWalkPoint(state.points.last, position),
          ],
        );
        _persistPoint(state.points.last);
      } catch (_) {
        // No fresh GPS fix means no evidence of a stop.
      } finally {
        _stationarySampleInFlight = false;
      }
    });
  }

  Future<void> _startTracking() async {
    _positionSubscription?.cancel();
    _locationWaitTimer?.cancel();
    if (state.status != WalkStatus.inProgress || state.isSimulating) return;
    state = state.copyWith(
      locationTrackingStatus: LocationTrackingStatus.waiting,
    );

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (state.status != WalkStatus.inProgress) return;
      if (!serviceEnabled) {
        state = state.copyWith(
          locationTrackingStatus: LocationTrackingStatus.serviceDisabled,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (state.status != WalkStatus.inProgress) return;
      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          locationTrackingStatus:
              LocationTrackingStatus.permissionDeniedForever,
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          locationTrackingStatus: LocationTrackingStatus.permissionDenied,
        );
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
              distanceFilter: 15,
              activityType: ActivityType.fitness,
              allowBackgroundLocationUpdates: true,
              pauseLocationUpdatesAutomatically: false,
              showBackgroundLocationIndicator: true,
            )
          : AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 15,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: '산책 중',
                notificationText: '경로를 기록하고 있습니다.',
                enableWakeLock: true,
              ),
            );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (position) {
              if (state.status != WalkStatus.inProgress || _completing) return;
              _locationWaitTimer?.cancel();
              if (state.locationTrackingStatus !=
                  LocationTrackingStatus.tracking) {
                state = state.copyWith(
                  locationTrackingStatus: LocationTrackingStatus.tracking,
                );
              }
              final now = DateTime.now();
              final recordedAt = position.timestamp;
              final lastPoint = state.points.isEmpty ? null : state.points.last;
              if (isFreshWalkPosition(
                    positionRecordedAt: recordedAt,
                    now: now,
                    lastPoint: null,
                  ) &&
                  position.accuracy.isFinite &&
                  position.accuracy >= 0 &&
                  position.accuracy <= 40) {
                _lastStreamFixAt = now;
              }
              if (!isFreshWalkPosition(
                    positionRecordedAt: recordedAt,
                    now: now,
                    lastPoint: lastPoint,
                  ) ||
                  !shouldRecordWalkPosition(
                    lastPoint: lastPoint,
                    lat: position.latitude,
                    lng: position.longitude,
                    accuracy: position.accuracy,
                    recordedAt: recordedAt,
                    segmentStart: _nextPointStartsSegment,
                  )) {
                return;
              }

              final segmentStart = _nextPointStartsSegment;
              _nextPointStartsSegment = false;
              // 포인트 기록 + 거리 계산
              final newPoint = WalkPoint(
                lat: position.latitude,
                lng: position.longitude,
                recordedAt: recordedAt,
                accuracy: position.accuracy,
                segmentStart: segmentStart,
              );

              double addedDistance = 0;
              if (lastPoint != null && !segmentStart) {
                addedDistance = Geolocator.distanceBetween(
                  lastPoint.lat,
                  lastPoint.lng,
                  position.latitude,
                  position.longitude,
                );
              }
              if (position.speed.isFinite && position.speed > 0.8 ||
                  lastPoint != null &&
                      !segmentStart &&
                      addedDistance /
                              (recordedAt
                                      .difference(lastPoint.recordedAt)
                                      .inMilliseconds /
                                  1000) >
                          0.8) {
                _lastMovingFixAt = now;
              }

              state = state.copyWith(
                points: [...state.points, newPoint],
                distanceMeters: state.distanceMeters + addedDistance,
                currentPosition: position,
              );
              _persistPoint(newPoint);

              // 위치 콜백에서 직접 서버 핑 — 백그라운드에서도 동작
              final session = state.session;
              if (session == null || state.status != WalkStatus.inProgress) {
                return;
              }

              if (_lastPingAt == null ||
                  now.difference(_lastPingAt!).inSeconds >=
                      _pingIntervalSeconds) {
                _lastPingAt = now;
                _repository
                    .updateLocation(
                      session.id,
                      position.latitude,
                      position.longitude,
                    )
                    .catchError((e) {
                      debugPrint('[핑] 위치 업데이트 실패: $e');
                      _handlePingError(e);
                    });
              }
            },
            onError: (Object error) {
              debugPrint('[위치] 위치 스트림 오류: $error');
              _locationWaitTimer?.cancel();
              if (state.status == WalkStatus.inProgress) {
                state = state.copyWith(
                  locationTrackingStatus: LocationTrackingStatus.error,
                );
              }
            },
          );

      _locationWaitTimer = Timer(_locationWaitTimeout, () {
        if (state.status == WalkStatus.inProgress &&
            state.locationTrackingStatus == LocationTrackingStatus.waiting) {
          state = state.copyWith(
            locationTrackingStatus: LocationTrackingStatus.timedOut,
          );
        }
      });
    } catch (error) {
      debugPrint('[위치] 위치 추적 시작 실패: $error');
      if (state.status == WalkStatus.inProgress) {
        state = state.copyWith(
          locationTrackingStatus: LocationTrackingStatus.error,
        );
      }
    }
  }

  Future<void> retryLocationTracking() async {
    if (state.status != WalkStatus.inProgress || state.isSimulating) return;
    await _startTracking();
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  void dispose() {
    _timer?.cancel();
    _simTimer?.cancel();
    _simPingTimer?.cancel();
    _locationWaitTimer?.cancel();
    _stationarySampleTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
