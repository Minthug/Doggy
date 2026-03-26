import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  NaverMapController? _mapController;
  NLatLng? _currentPosition;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = NLatLng(position.latitude, position.longitude);
        _locationLoading = false;
      });

      _mapController?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: _currentPosition!,
          zoom: 15,
        ),
      );
    } catch (e) {
      // 위치 권한 거부 등 → 서울 시청으로 기본값
      setState(() {
        _currentPosition = const NLatLng(37.5665, 126.9780);
        _locationLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '주변 장소',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
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
                    target: _currentPosition!,
                    zoom: 15,
                  ),
                );
              }
            },
          ),
          if (_locationLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
