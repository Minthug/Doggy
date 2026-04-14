import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/place_model.dart';
import '../../domain/providers/place_provider.dart';
import 'place_register_screen.dart';

class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  NaverMapController? _mapController;
  NLatLng? _currentPosition;
  Place? _selectedPlace;
  bool _locationLoading = true;
  bool _pinMode = false;       // 장소 등록 모드
  NLatLng? _pinnedPosition;   // 핀 찍은 좌표

  static const _categories = [
    (label: '전체', value: null),
    (label: '🏥 동물병원', value: 'HOSPITAL'),
    (label: '🌳 공원', value: 'PARK'),
    (label: '☕ 카페', value: 'CAFE'),
    (label: '🛍️ 펫샵', value: 'PET_SHOP'),
    (label: '🏨 펫호텔', value: 'PET_HOTEL'),
    (label: '🏪 편의점', value: 'CONVENIENCE'),
    (label: '🤖 무인스토어', value: 'UNMANNED_STORE'),
    (label: '🍽️ 동반식당', value: 'RESTAURANT'),
    (label: '✂️ 미용실', value: 'GROOMING'),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('위치 서비스가 꺼져 있습니다');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 거부됐습니다');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
        _locationLoading = false;
      });
      _mapController?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: _currentPosition!, zoom: 15),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentPosition = const NLatLng(37.5665, 126.9780);
        _locationLoading = false;
      });
    }
  }

  void _showPinConfirmSheet(NLatLng coord) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Color(0xFF4CAF50), size: 40),
            const SizedBox(height: 12),
            const Text('이 위치에 장소를 등록할까요?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              '위도 ${coord.latitude.toStringAsFixed(5)}, 경도 ${coord.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _pinnedPosition = null);
                    },
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _pinMode = false);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaceRegisterScreen(
                            lat: coord.latitude,
                            lng: coord.longitude,
                          ),
                        ),
                      );
                      if (result == true && _currentPosition != null) {
                        ref.invalidate(nearbyPlacesProvider);
                      }
                    },
                    child: const Text('등록하기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addMarkers(List<Place> places) async {
    if (_mapController == null) return;
    await _mapController!.clearOverlays();

    for (final place in places) {
      final marker = NMarker(
        id: 'place_${place.id}',
        position: NLatLng(place.lat, place.lng),
        caption: NOverlayCaption(
          text: place.name,
          textSize: 12,
        ),
        iconTintColor: _markerColor(place.category),
      );
      marker.setOnTapListener((_) {
        setState(() => _selectedPlace = place);
      });
      await _mapController!.addOverlay(marker);
    }
  }

  Color _markerColor(String category) {
    switch (category) {
      case 'HOSPITAL':        return Colors.red;
      case 'PARK':            return Colors.green;
      case 'CAFE':            return Colors.brown;
      case 'PET_SHOP':        return Colors.orange;
      case 'PET_HOTEL':       return Colors.purple;
      case 'CONVENIENCE':     return Colors.teal;
      case 'UNMANNED_STORE':  return Colors.indigo;
      case 'RESTAURANT':      return Colors.deepOrange;
      case 'GROOMING':        return Colors.pink;
      default:                return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final location = _currentPosition;

    if (location != null) {
      final placesAsync = ref.watch(
          nearbyPlacesProvider((lat: location.latitude, lng: location.longitude)));
      placesAsync.when(
        data: (places) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _addMarkers(places));
        },
        loading: () {},
        error: (e, _) => debugPrint('[MapTab] 장소 로드 실패: $e'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('주변 장소',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              _pinMode ? Icons.close : Icons.add_location_alt_outlined,
              color: _pinMode ? Colors.red : const Color(0xFF4CAF50),
            ),
            onPressed: () {
              setState(() {
                _pinMode = !_pinMode;
                _pinnedPosition = null;
              });
              if (_pinMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('등록할 장소 위치를 지도에서 탭해주세요'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _currentPosition ?? const NLatLng(37.5665, 126.9780),
                zoom: 15,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                controller.updateCamera(
                  NCameraUpdate.scrollAndZoomTo(
                      target: _currentPosition!, zoom: 15),
                );
              }
              // 지도 준비되면 마커 로드
              if (location != null) {
                ref
                    .read(nearbyPlacesProvider(
                            (lat: location.latitude, lng: location.longitude)))
                    .whenData((places) => _addMarkers(places));
              }
            },
            onMapTapped: (point, coord) {
              if (_pinMode) {
                setState(() => _pinnedPosition = coord);
                _showPinConfirmSheet(coord);
              } else {
                setState(() => _selectedPlace = null);
              }
            },
          ),

          // 로딩
          if (_locationLoading)
            const Center(child: CircularProgressIndicator()),

          // 카테고리 필터
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((cat) {
                  final selected = selectedCategory == cat.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(selectedCategoryProvider.notifier)
                            .state = cat.value;
                        setState(() => _selectedPlace = null);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF4CAF50)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 핀 모드 안내 배너
          if (_pinMode)
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('등록할 위치를 탭해주세요',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // 선택된 장소 팝업
          if (_selectedPlace != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _PlaceCard(
                place: _selectedPlace!,
                onClose: () => setState(() => _selectedPlace = null),
              ),
            ),
        ],
      ),
    );
  }
}

// 장소 팝업 카드
class _PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onClose;

  const _PlaceCard({required this.place, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(place.categoryEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  place.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 주소
          if (place.address != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place.address!,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          // 전화번호
          if (place.phone != null && place.phone!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(place.phone!,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // 배지
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (place.isOpen24h) _badge('24시간', Colors.blue),
              if (place.isEmergency) _badge('응급', Colors.red),
              if (place.allowsDogs) _badge('반려견 가능', Colors.green),
              if (place.isVerified) _badge('인증', Colors.orange),
              if (place.helpfulCount > 0)
                _badge('도움돼요 ${place.helpfulCount}', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
