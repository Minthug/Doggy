import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/place_repository.dart';
import '../../domain/providers/place_provider.dart';

class PlaceRegisterScreen extends ConsumerStatefulWidget {
  final double lat;
  final double lng;

  const PlaceRegisterScreen({super.key, required this.lat, required this.lng});

  @override
  ConsumerState<PlaceRegisterScreen> createState() =>
      _PlaceRegisterScreenState();
}

class _PlaceRegisterScreenState extends ConsumerState<PlaceRegisterScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String _category = 'CAFE';
  bool _isOpen24h = false;
  bool _isEmergency = false;
  bool _allowsDogs = true;
  bool _isLoading = false;

  static const _categories = [
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
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소 이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(placeRepositoryProvider).create(
            name: _nameController.text.trim(),
            category: _category,
            lat: widget.lat,
            lng: widget.lng,
            address: _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            isOpen24h: _isOpen24h,
            isEmergency: _isEmergency,
            allowsDogs: _allowsDogs,
          );

      // 주변 장소 캐시 무효화
      ref.invalidate(nearbyPlacesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장소가 등록됐습니다')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록에 실패했습니다. 다시 시도해주세요')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('장소 등록',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 위치 표시
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  Text(
                    '위도 ${widget.lat.toStringAsFixed(5)}, 경도 ${widget.lng.toStringAsFixed(5)}',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle('카테고리 *'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _category == cat.value;
                return ChoiceChip(
                  label: Text(cat.label),
                  selected: selected,
                  selectedColor: const Color(0xFF4CAF50),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _category = cat.value),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _sectionTitle('장소 정보'),
            const SizedBox(height: 10),

            _inputField(
              controller: _nameController,
              label: '장소 이름 *',
              hint: '예) 멍멍이 카페, 강아지 공원',
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _addressController,
              label: '주소',
              hint: '예) 서울시 강남구 ...',
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _phoneController,
              label: '전화번호',
              hint: '예) 02-1234-5678',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            _sectionTitle('상세 정보'),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('24시간 운영'),
                    value: _isOpen24h,
                    activeColor: const Color(0xFF4CAF50),
                    onChanged: (v) => setState(() => _isOpen24h = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('응급 진료 가능'),
                    subtitle: const Text('동물병원의 경우'),
                    value: _isEmergency,
                    activeColor: Colors.red,
                    onChanged: (v) => setState(() => _isEmergency = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('반려견 동반 가능'),
                    value: _allowsDogs,
                    activeColor: const Color(0xFF4CAF50),
                    onChanged: (v) => setState(() => _allowsDogs = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('등록하기',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87));

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50)),
        ),
      ),
    );
  }
}
