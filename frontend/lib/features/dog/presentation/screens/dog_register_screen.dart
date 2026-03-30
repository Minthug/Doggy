import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dog_model.dart';
import '../../data/repositories/dog_repository.dart';
import '../../domain/providers/dog_provider.dart';

class DogRegisterScreen extends ConsumerStatefulWidget {
  final Dog? dog; // null이면 등록 모드, 값이 있으면 수정 모드

  const DogRegisterScreen({super.key, this.dog});

  @override
  ConsumerState<DogRegisterScreen> createState() => _DogRegisterScreenState();
}

class _DogRegisterScreenState extends ConsumerState<DogRegisterScreen> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();

  String _gender = 'MALE';
  bool _isNeutered = false;
  DateTime? _birthDate;
  bool _isLoading = false;

  bool get _isEditMode => widget.dog != null;

  @override
  void initState() {
    super.initState();
    final dog = widget.dog;
    if (dog != null) {
      _nameController.text = dog.name;
      _breedController.text = dog.breed ?? '';
      _weightController.text = dog.weightKg?.toString() ?? '';
      _gender = dog.gender ?? 'MALE';
      _isNeutered = dog.isNeutered;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '생년월일 선택',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isEditMode) {
        await ref.read(dogRepositoryProvider).update(
              dogId: widget.dog!.id,
              name: _nameController.text.trim(),
              breed: _breedController.text.trim(),
              birthDate: _formatDate(_birthDate),
              weightKg: _weightController.text.isNotEmpty
                  ? double.tryParse(_weightController.text)
                  : null,
              gender: _gender,
              isNeutered: _isNeutered,
            );
      } else {
        await ref.read(dogRepositoryProvider).create(
              name: _nameController.text.trim(),
              breed: _breedController.text.trim(),
              birthDate: _formatDate(_birthDate),
              weightKg: _weightController.text.isNotEmpty
                  ? double.tryParse(_weightController.text)
                  : null,
              gender: _gender,
              isNeutered: _isNeutered,
            );
      }
      ref.invalidate(myDogsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? '수정에 실패했습니다' : '등록에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('반려견 삭제'),
        content: Text('${widget.dog!.name}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(dogRepositoryProvider).delete(widget.dog!.id);
      ref.invalidate(myDogsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다')),
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
        title: Text(_isEditMode ? '반려견 정보 수정' : '반려견 등록'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: _isEditMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _isLoading ? null : _delete,
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 사진 자리
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.pets,
                        color: Color(0xFF4CAF50), size: 48),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle('기본 정보'),
            const SizedBox(height: 12),

            _inputField(
              controller: _nameController,
              label: '이름 *',
              hint: '예) 초코, 콩이',
            ),
            const SizedBox(height: 12),

            _inputField(
              controller: _breedController,
              label: '견종',
              hint: '예) 말티즈, 포메라니안',
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _pickBirthDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _birthDate == null
                          ? '생년월일'
                          : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                      style: TextStyle(
                        fontSize: 16,
                        color: _birthDate == null ? Colors.grey : Colors.black,
                      ),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            _inputField(
              controller: _weightController,
              label: '몸무게 (kg)',
              hint: '예) 3.5',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),

            _sectionTitle('성별'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _genderButton(label: '남아 ♂', value: 'MALE')),
                const SizedBox(width: 12),
                Expanded(child: _genderButton(label: '여아 ♀', value: 'FEMALE')),
              ],
            ),
            const SizedBox(height: 24),

            _sectionTitle('중성화'),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('중성화 했어요'),
                value: _isNeutered,
                onChanged: (v) => setState(() => _isNeutered = v),
                activeThumbColor: const Color(0xFF4CAF50),
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
                    : Text(
                        _isEditMode ? '수정하기' : '등록하기',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87));
  }

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

  Widget _genderButton({required String label, required String value}) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4CAF50) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
