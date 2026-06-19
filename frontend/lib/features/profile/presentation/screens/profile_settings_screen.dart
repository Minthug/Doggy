import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/api_client.dart';
import '../../../home/data/repositories/home_repository.dart';
import '../../../home/domain/providers/home_provider.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  final String initialNickname;
  final String? initialProfileImage;
  final bool nicknameChanged;

  const ProfileSettingsScreen({
    super.key,
    required this.initialNickname,
    this.initialProfileImage,
    this.nicknameChanged = false,
  });

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late final TextEditingController _nicknameController;
  File? _imageFile;
  bool _clearImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _clearImage = false;
      });
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imageFile != null ||
                (widget.initialProfileImage != null && !_clearImage))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('사진 삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _imageFile = null;
                    _clearImage = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_imageFile != null) {
      return CircleAvatar(
        radius: 52,
        backgroundImage: FileImage(_imageFile!),
      );
    }
    if (!_clearImage && widget.initialProfileImage != null) {
      final img = widget.initialProfileImage!;
      if (img.startsWith('data:image')) {
        return CircleAvatar(
          radius: 52,
          backgroundImage: MemoryImage(base64Decode(img.split(',').last)),
        );
      }
      return CircleAvatar(
        radius: 52,
        backgroundImage: NetworkImage(img),
      );
    }
    return CircleAvatar(
      radius: 52,
      backgroundColor: const Color(0xFFE8F5E9),
      child: const Icon(Icons.person, size: 52, color: Color(0xFF4CAF50)),
    );
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? profileImage;
      if (_imageFile != null) {
        profileImage = await ref.read(imageUploadProvider).upload(_imageFile!);
      } else if (_clearImage) {
        profileImage = null;
      } else {
        profileImage = widget.initialProfileImage;
      }

      await ref.read(homeRepositoryProvider).updateProfile(
            nickname: nickname,
            profileImage: profileImage,
          );

      ref.invalidate(userProfileProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final msg = (e is Exception)
            ? e.toString().contains('닉네임') ? '닉네임은 1회만 변경할 수 있습니다' : '저장에 실패했습니다'
            : '저장에 실패했습니다';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canChangeNickname = !widget.nicknameChanged;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('프로필 설정',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장',
                    style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showImageOptions,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _buildAvatar(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('닉네임',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      if (!canChangeNickname)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('변경 완료',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('1회만 변경 가능',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF4CAF50))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nicknameController,
                    enabled: canChangeNickname,
                    maxLength: 20,
                    decoration: InputDecoration(
                      hintText: '닉네임을 입력하세요',
                      filled: true,
                      fillColor: canChangeNickname
                          ? const Color(0xFFF9F9F9)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      counterText: '',
                    ),
                  ),
                  if (!canChangeNickname)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '닉네임은 1회만 변경할 수 있습니다.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
