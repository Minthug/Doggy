import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../home/data/repositories/home_repository.dart';
import '../../../home/domain/providers/home_provider.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  final String initialNickname;
  final String? initialProfileImage;

  const ProfileSettingsScreen({
    super.key,
    required this.initialNickname,
    this.initialProfileImage,
  });

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  File? _imageFile;
  bool _clearImage = false;
  bool _saving = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
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

  Future<String?> _encodeImage() async {
    if (_imageFile == null) return null;
    final bytes = await _imageFile!.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
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
    setState(() => _saving = true);
    try {
      String? profileImage;
      if (_imageFile != null) {
        profileImage = await _encodeImage();
      } else if (_clearImage) {
        profileImage = null;
      } else {
        profileImage = widget.initialProfileImage;
      }

      await ref.read(homeRepositoryProvider).updateProfile(
            nickname: widget.initialNickname,
            profileImage: profileImage,
          );

      ref.invalidate(userProfileProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장에 실패했습니다')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('프로필 사진 변경',
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: GestureDetector(
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
        ),
      ),
    );
  }
}
