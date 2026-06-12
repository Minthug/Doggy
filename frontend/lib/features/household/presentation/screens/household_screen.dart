import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/household_model.dart';
import '../../data/repositories/household_repository.dart';
import '../../domain/providers/household_provider.dart';

class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdAsync = ref.watch(myHouseholdProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('가족 관리', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: householdAsync.when(
        data: (household) => household == null
            ? _NoHouseholdView(onRefresh: () => ref.invalidate(myHouseholdProvider))
            : _HouseholdView(household: household, onRefresh: () => ref.invalidate(myHouseholdProvider)),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _NoHouseholdView(onRefresh: () => ref.invalidate(myHouseholdProvider)),
      ),
    );
  }
}

// 가구 없음 — 생성 or 참여
class _NoHouseholdView extends ConsumerWidget {
  final VoidCallback onRefresh;

  const _NoHouseholdView({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_outlined, size: 72, color: Color(0xFF4CAF50)),
          const SizedBox(height: 16),
          const Text('아직 가구가 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            '가구를 만들거나 초대 코드로 가족에게 참여하세요.\n가구 강아지를 함께 산책 기록할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add_home),
              label: const Text('가구 만들기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showJoinDialog(context, ref),
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('초대 코드로 참여'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가구 만들기'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '예) 김씨 가족',
            labelText: '가구 이름',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(householdRepositoryProvider).create(ctrl.text.trim());
                onRefresh();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('가구 생성에 실패했습니다')));
                }
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대 코드로 참여'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '8자리 코드 입력',
            labelText: '초대 코드',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(householdRepositoryProvider).join(ctrl.text.trim());
                onRefresh();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('유효하지 않은 초대 코드입니다')));
                }
              }
            },
            child: const Text('참여'),
          ),
        ],
      ),
    );
  }
}

// 가구 있음 — 현황 표시
class _HouseholdView extends ConsumerWidget {
  final Household household;
  final VoidCallback onRefresh;

  const _HouseholdView({required this.household, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 가구 이름 + 초대 코드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.home, size: 40, color: Color(0xFF4CAF50)),
                const SizedBox(height: 8),
                Text(household.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('초대 코드', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      household.inviteCode,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: household.inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('초대 코드가 복사됐습니다')));
                      },
                    ),
                  ],
                ),
                // 오너만 코드 재발급 가능
                if (household.members.any((m) => m.isOwner))
                  TextButton(
                    onPressed: () => _refreshCode(context, ref),
                    child: const Text('코드 재발급', style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 멤버 목록
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('가족 ${household.members.length}명',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...household.members.map((m) => _MemberRow(member: m)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 탈퇴 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLeave(context, ref),
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              label: const Text('가구 탈퇴', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshCode(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코드 재발급'),
        content: const Text('기존 초대 코드는 더 이상 사용할 수 없어요. 재발급할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('재발급'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(householdRepositoryProvider).refreshInviteCode();
      onRefresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('재발급에 실패했습니다')));
      }
    }
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가구 탈퇴'),
        content: const Text('탈퇴하면 가구 강아지에 접근할 수 없어요. 정말 탈퇴할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('탈퇴', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(householdRepositoryProvider).leave();
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _MemberRow extends StatelessWidget {
  final HouseholdMember member;

  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage: member.profileImage != null
                ? NetworkImage(member.profileImage!)
                : null,
            child: member.profileImage == null
                ? const Icon(Icons.person, size: 20, color: Color(0xFF4CAF50))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(member.nickname,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: member.isOwner
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              member.isOwner ? '오너' : '멤버',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: member.isOwner ? const Color(0xFF4CAF50) : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
