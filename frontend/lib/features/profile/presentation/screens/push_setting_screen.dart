import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

final _pushSettingProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/users/me/push-settings');
  return response.data as Map<String, dynamic>;
});

class PushSettingScreen extends ConsumerStatefulWidget {
  const PushSettingScreen({super.key});

  @override
  ConsumerState<PushSettingScreen> createState() => _PushSettingScreenState();
}

class _PushSettingScreenState extends ConsumerState<PushSettingScreen> {
  bool _walkReminderEnabled = true;
  int _reminderIntervalHours = 8;
  bool _weatherAlertEnabled = true;
  int _weatherAlertHour = 7;
  int _weatherAlertMinute = 0;
  bool _birthdayAlertEnabled = true;
  bool _healthCheckupAlertEnabled = true;
  bool _loaded = false;

  final _intervalOptions = [4, 6, 8, 12, 24];

  @override
  Widget build(BuildContext context) {
    final settingAsync = ref.watch(_pushSettingProvider);

    settingAsync.whenData((data) {
      if (!_loaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _walkReminderEnabled = data['walkReminderEnabled'] ?? true;
              _reminderIntervalHours = data['reminderIntervalHours'] ?? 8;
              _weatherAlertEnabled = data['weatherAlertEnabled'] ?? true;
              _weatherAlertHour = data['weatherAlertHour'] ?? 7;
              _weatherAlertMinute = data['weatherAlertMinute'] ?? 0;
              _birthdayAlertEnabled = data['birthdayAlertEnabled'] ?? true;
              _healthCheckupAlertEnabled = data['healthCheckupAlertEnabled'] ?? true;
              _loaded = true;
            });
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('알림 설정',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('저장',
                style: TextStyle(
                    color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: settingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('설정을 불러오지 못했습니다')),
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingCard(
              children: [
                SwitchListTile(
                  title: const Text('산책 리마인더',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('일정 시간 산책을 안 하면 알림을 보내드려요'),
                  value: _walkReminderEnabled,
                  activeColor: const Color(0xFF4CAF50),
                  onChanged: (v) => setState(() => _walkReminderEnabled = v),
                ),
                if (_walkReminderEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('알림 주기',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: _intervalOptions.map((hours) {
                            final selected = _reminderIntervalHours == hours;
                            return ChoiceChip(
                              label: Text(hours == 24
                                  ? '하루 1회'
                                  : '$hours시간마다'),
                              selected: selected,
                              selectedColor: const Color(0xFF4CAF50),
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (_) => setState(
                                  () => _reminderIntervalHours = hours),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _SettingCard(
              children: [
                SwitchListTile(
                  title: const Text('생일 알림',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('반려견 생일날 아침 8시에 알림을 보내드려요 🎂'),
                  value: _birthdayAlertEnabled,
                  activeColor: const Color(0xFF4CAF50),
                  onChanged: (v) => setState(() => _birthdayAlertEnabled = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SettingCard(
              children: [
                SwitchListTile(
                  title: const Text('정기 건강검진 알림',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('매월 1일 건강검진을 상기시켜 드려요 🏥'),
                  value: _healthCheckupAlertEnabled,
                  activeColor: const Color(0xFF4CAF50),
                  onChanged: (v) => setState(() => _healthCheckupAlertEnabled = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SettingCard(
              children: [
                SwitchListTile(
                  title: const Text('날씨 알림',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('산책하기 좋은 날씨일 때 알림을 보내드려요'),
                  value: _weatherAlertEnabled,
                  activeColor: const Color(0xFF4CAF50),
                  onChanged: (v) => setState(() => _weatherAlertEnabled = v),
                ),
                if (_weatherAlertEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('알림 받을 시각',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: GestureDetector(
                      onTap: _pickWeatherAlertTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_weatherAlertHour.toString().padLeft(2, '0')}:${_weatherAlertMinute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickWeatherAlertTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _weatherAlertHour, minute: _weatherAlertMinute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _weatherAlertHour = picked.hour;
        _weatherAlertMinute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/users/me/push-settings', data: {
        'walkReminderEnabled': _walkReminderEnabled,
        'reminderIntervalHours': _reminderIntervalHours,
        'weatherAlertEnabled': _weatherAlertEnabled,
        'weatherAlertHour': _weatherAlertHour,
        'weatherAlertMinute': _weatherAlertMinute,
        'birthdayAlertEnabled': _birthdayAlertEnabled,
        'healthCheckupAlertEnabled': _healthCheckupAlertEnabled,
      });
      if (mounted) {
        ref.invalidate(_pushSettingProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 설정이 저장됐습니다')),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${e.message}')),
        );
      }
    }
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(children: children),
    );
  }
}
