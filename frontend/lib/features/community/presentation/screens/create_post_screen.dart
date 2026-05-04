import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/community_post_model.dart';
import '../../data/repositories/community_repository.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  PostType _type = PostType.GENERAL;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _dogNameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _dogNameCtrl.dispose();
    _breedCtrl.dispose();
    _areaCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  bool get _isDogPost => _type == PostType.LOST || _type == PostType.FOUND;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(communityRepositoryProvider).create(
            type: _type,
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text.trim(),
            dogName: _dogNameCtrl.text.trim().isEmpty ? null : _dogNameCtrl.text.trim(),
            breed: _breedCtrl.text.trim().isEmpty ? null : _breedCtrl.text.trim(),
            lastSeenArea: _areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim(),
            contactInfo: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
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
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('등록', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 타입 선택
            const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: PostType.values.map((t) {
                final selected = _type == t;
                Color color;
                switch (t) {
                  case PostType.LOST:    color = Colors.red; break;
                  case PostType.FOUND:   color = Colors.orange; break;
                  case PostType.GENERAL: color = const Color(0xFF4CAF50); break;
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? color : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? color : Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Text(t.label,
                              style: TextStyle(
                                  color: selected ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _field(
              controller: _titleCtrl,
              label: '제목',
              validator: (v) => v == null || v.trim().isEmpty ? '제목을 입력해주세요' : null,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _contentCtrl,
              label: '내용',
              maxLines: 5,
              validator: (v) => v == null || v.trim().isEmpty ? '내용을 입력해주세요' : null,
            ),
            if (_isDogPost) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              const Text('강아지 정보',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              _field(controller: _dogNameCtrl, label: '강아지 이름'),
              const SizedBox(height: 12),
              _field(controller: _breedCtrl, label: '견종'),
              const SizedBox(height: 12),
              _field(
                controller: _areaCtrl,
                label: _type == PostType.LOST ? '마지막 목격 장소' : '목격 장소',
              ),
              const SizedBox(height: 12),
              _field(controller: _contactCtrl, label: '연락처'),
            ],
          ],
        ),
      ),
    );
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
