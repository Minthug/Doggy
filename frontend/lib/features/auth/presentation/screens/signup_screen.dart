import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  DateTime? _birthDate;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      helpText: '생년월일 선택',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이용약관에 동의해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authActionProvider).signUp(
            _emailController.text.trim(),
            _passwordController.text,
            _nicknameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            birthDate: _formatDate(_birthDate),
          );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } catch (e) {
      debugPrint('[SignUp Error] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입에 실패했습니다. 다시 시도해주세요')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('회원가입',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 섹션: 기본 정보
            _sectionTitle('기본 정보'),
            const SizedBox(height: 12),

            // 닉네임
            TextFormField(
              controller: _nicknameController,
              decoration: _inputDeco('닉네임', Icons.person_outline),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '닉네임을 입력해주세요';
                if (v.trim().length > 20) return '닉네임은 20자 이하로 입력해주세요';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // 이메일
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco('이메일', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '이메일을 입력해주세요';
                final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
                if (!emailRegex.hasMatch(v.trim())) return '올바른 이메일 형식이 아닙니다';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // 비밀번호
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _inputDeco('비밀번호 (8자 이상)', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '비밀번호를 입력해주세요';
                if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // 비밀번호 확인
            TextFormField(
              controller: _passwordConfirmController,
              obscureText: _obscureConfirm,
              decoration:
                  _inputDeco('비밀번호 확인', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '비밀번호 확인을 입력해주세요';
                if (v != _passwordController.text) return '비밀번호가 일치하지 않습니다';
                return null;
              },
            ),

            const SizedBox(height: 24),
            _sectionTitle('추가 정보'),
            const SizedBox(height: 12),

            // 전화번호
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDeco('전화번호 (예: 01012345678)', Icons.phone_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // 선택
                final phoneRegex = RegExp(r'^01[0-9]{8,9}$');
                if (!phoneRegex.hasMatch(v.trim())) return '올바른 전화번호 형식이 아닙니다 (숫자만 입력)';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // 지역
            TextFormField(
              controller: _addressController,
              decoration: _inputDeco('거주 지역 (예: 서울 강남구)', Icons.location_on_outlined),
            ),
            const SizedBox(height: 14),

            // 생년월일
            GestureDetector(
              onTap: _pickBirthDate,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: _inputDeco(
                    _birthDate != null
                        ? '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일'
                        : '생년월일 선택',
                    Icons.cake_outlined,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 이용약관 동의
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _agreedToTerms,
                    onChanged: (v) =>
                        setState(() => _agreedToTerms = v ?? false),
                    title: const Text(
                      '[필수] 이용약관 및 개인정보 처리방침에 동의합니다',
                      style: TextStyle(fontSize: 13),
                    ),
                    activeColor: const Color(0xFF4CAF50),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      '수집 항목: 닉네임, 이메일, 전화번호, 생년월일\n'
                      '수집 목적: 서비스 제공 및 반려견 산책 기록 관리\n'
                      '보유 기간: 회원 탈퇴 시까지',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 가입하기 버튼
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('가입하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4CAF50)),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
