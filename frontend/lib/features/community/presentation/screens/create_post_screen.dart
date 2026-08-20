import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/community_post_model.dart';
import '../../data/repositories/community_repository.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final CommunityPost? relatedLostPost;
  const CreatePostScreen({super.key, this.relatedLostPost});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  PostType _type = PostType.ADOPTION;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _dogNameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _productNameCtrl = TextEditingController();
  final _reviewSummaryCtrl = TextEditingController();
  final _prosCtrl = TextEditingController();
  final _consCtrl = TextEditingController();
  DateTime? _lastSeenAt;
  double? _lat;
  double? _lng;
  bool _loading = false;
  int? _relatedPostId;
  int _ratingPercent = 85;

  @override
  void initState() {
    super.initState();
    final related = widget.relatedLostPost;
    if (related != null) {
      _type = PostType.FOUND;
      _relatedPostId = related.id;
      _dogNameCtrl.text = related.dogName ?? '';
      _breedCtrl.text = related.breed ?? '';
      _titleCtrl.text = '${related.dogName ?? '강아지'}를 목격했습니다';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _dogNameCtrl.dispose();
    _breedCtrl.dispose();
    _areaCtrl.dispose();
    _contactCtrl.dispose();
    _productNameCtrl.dispose();
    _reviewSummaryCtrl.dispose();
    _prosCtrl.dispose();
    _consCtrl.dispose();
    super.dispose();
  }

  bool get _isDogPost =>
      _type == PostType.LOST ||
      _type == PostType.FOUND ||
      _type == PostType.ADOPTION;
  bool get _isReview => _type.isReview;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    setState(() {
      _lastSeenAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<({double lat, double lng})>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(initialLat: _lat, initialLng: _lng),
      ),
    );
    if (result != null) {
      setState(() {
        _lat = result.lat;
        _lng = result.lng;
      });
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .create(
            type: _type,
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text.trim(),
            dogName: _dogNameCtrl.text.trim().isEmpty
                ? null
                : _dogNameCtrl.text.trim(),
            breed: _breedCtrl.text.trim().isEmpty
                ? null
                : _breedCtrl.text.trim(),
            lastSeenArea: _areaCtrl.text.trim().isEmpty
                ? null
                : _areaCtrl.text.trim(),
            lastSeenAt: _lastSeenAt,
            lat: _lat,
            lng: _lng,
            contactInfo: _contactCtrl.text.trim().isEmpty
                ? null
                : _contactCtrl.text.trim(),
            productName: _productNameCtrl.text.trim().isEmpty
                ? null
                : _productNameCtrl.text.trim(),
            ratingPercent: _isReview ? _ratingPercent : null,
            reviewSummary: _reviewSummaryCtrl.text.trim().isEmpty
                ? null
                : _reviewSummaryCtrl.text.trim(),
            pros: _prosCtrl.text.trim().isEmpty ? null : _prosCtrl.text.trim(),
            cons: _consCtrl.text.trim().isEmpty ? null : _consCtrl.text.trim(),
            relatedPostId: _relatedPostId,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('글쓰기'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '등록',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 타입 선택
            const Text(
              '카테고리',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PostType.values.map((t) {
                final selected = _type == t;
                final color = _typeColor(t);
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? color : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      t.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _field(
              controller: _titleCtrl,
              label: _isReview ? '리뷰 제목' : '제목',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '제목을 입력해주세요' : null,
            ),
            const SizedBox(height: 16),
            if (_isReview) ...[
              _ReviewForm(
                productNameCtrl: _productNameCtrl,
                summaryCtrl: _reviewSummaryCtrl,
                prosCtrl: _prosCtrl,
                consCtrl: _consCtrl,
                ratingPercent: _ratingPercent,
                onRatingChanged: (value) =>
                    setState(() => _ratingPercent = value.round()),
              ),
              const SizedBox(height: 16),
            ],
            _field(
              controller: _contentCtrl,
              label: _isReview ? '상세 리뷰' : '내용',
              maxLines: 5,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '내용을 입력해주세요' : null,
            ),
            if (_isDogPost) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                '강아지 정보',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _field(controller: _dogNameCtrl, label: '강아지 이름'),
              const SizedBox(height: 12),
              _field(controller: _breedCtrl, label: '견종'),
              const SizedBox(height: 12),
              _field(
                controller: _areaCtrl,
                label: _type == PostType.LOST
                    ? '마지막 목격 장소 (주소)'
                    : _type == PostType.FOUND
                    ? '목격 장소 (주소)'
                    : '지역 (주소)',
              ),
              const SizedBox(height: 12),

              // 시간 선택 (분양/입양 제외)
              if (_type != PostType.ADOPTION) ...[
                GestureDetector(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _lastSeenAt == null
                              ? (_type == PostType.LOST
                                    ? '마지막 목격 시간 선택'
                                    : '목격 시간 선택')
                              : _formatDateTime(_lastSeenAt!),
                          style: TextStyle(
                            fontSize: 14,
                            color: _lastSeenAt == null
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 지도 위치 선택
              GestureDetector(
                onTap: _pickLocation,
                child: Container(
                  height: _lat != null ? 180 : 54,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[50],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _lat != null
                      ? Stack(
                          children: [
                            NaverMap(
                              options: NaverMapViewOptions(
                                initialCameraPosition: NCameraPosition(
                                  target: NLatLng(_lat!, _lng!),
                                  zoom: 15,
                                ),
                                scrollGesturesEnable: false,
                                zoomGesturesEnable: false,
                                tiltGesturesEnable: false,
                                rotationGesturesEnable: false,
                                locationButtonEnable: false,
                              ),
                              onMapReady: (ctrl) {
                                ctrl.addOverlay(
                                  NMarker(
                                    id: 'picked',
                                    position: NLatLng(_lat!, _lng!),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  '위치 변경',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _type == PostType.LOST
                                  ? '마지막 목격 위치 지도에 표시 (선택)'
                                  : _type == PostType.FOUND
                                  ? '목격 위치 지도에 표시 (선택)'
                                  : '거주 지역 지도에 표시 (선택)',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              _field(controller: _contactCtrl, label: '연락처'),
            ],
          ],
        ),
      ),
    );
  }

  Color _typeColor(PostType t) {
    switch (t) {
      case PostType.LOST:
        return Colors.red;
      case PostType.FOUND:
        return Colors.orange;
      case PostType.ADOPTION:
        return const Color(0xFF7C4DFF);
      case PostType.FOOD_REVIEW:
        return const Color(0xFF2E7D32);
      case PostType.SUPPLY_REVIEW:
        return const Color(0xFF1565C0);
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _ReviewForm extends StatelessWidget {
  final TextEditingController productNameCtrl;
  final TextEditingController summaryCtrl;
  final TextEditingController prosCtrl;
  final TextEditingController consCtrl;
  final int ratingPercent;
  final ValueChanged<double> onRatingChanged;

  const _ReviewForm({
    required this.productNameCtrl,
    required this.summaryCtrl,
    required this.prosCtrl,
    required this.consCtrl,
    required this.ratingPercent,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = ratingPercent >= 70
        ? const Color(0xFF2E7D32)
        : ratingPercent >= 45
        ? const Color(0xFFFF9800)
        : const Color(0xFFD32F2F);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    '$ratingPercent%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '추천도',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Slider(
                      value: ratingPercent.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: color,
                      label: '$ratingPercent%',
                      onChanged: onRatingChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _reviewField(
            controller: productNameCtrl,
            label: '제품명',
            validator: (v) =>
                v == null || v.trim().isEmpty ? '제품명을 입력해주세요' : null,
          ),
          const SizedBox(height: 12),
          _reviewField(
            controller: summaryCtrl,
            label: '한줄평',
            validator: (v) =>
                v == null || v.trim().isEmpty ? '한줄평을 입력해주세요' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _reviewField(controller: prosCtrl, label: '좋았던 점'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _reviewField(controller: consCtrl, label: '아쉬운 점'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
    );
  }
}

// 지도에서 위치 찍기
class _MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const _MapPickerScreen({this.initialLat, this.initialLng});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  NaverMapController? _ctrl;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
    if (_lat == null) _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _ctrl?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: NLatLng(_lat!, _lng!), zoom: 16),
      );
      _updateMarker();
    } catch (_) {}
  }

  void _updateMarker() {
    if (_ctrl == null || _lat == null) return;
    _ctrl!.clearOverlays();
    _ctrl!.addOverlay(NMarker(id: 'pick', position: NLatLng(_lat!, _lng!)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 선택'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _lat == null
                ? null
                : () => Navigator.pop(context, (lat: _lat!, lng: _lng!)),
            child: const Text(
              '확인',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(_lat ?? 37.5665, _lng ?? 126.9780),
                zoom: 15,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (ctrl) {
              _ctrl = ctrl;
              if (_lat != null) _updateMarker();
            },
            onMapTapped: (point, coord) {
              setState(() {
                _lat = coord.latitude;
                _lng = coord.longitude;
              });
              _updateMarker();
            },
          ),
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: _HintBanner()),
          ),
        ],
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '지도를 탭해서 위치를 선택하세요',
        style: TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
