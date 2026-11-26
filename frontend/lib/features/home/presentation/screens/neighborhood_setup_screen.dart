import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../data/models/user_profile_model.dart';
import '../../domain/providers/home_provider.dart';

class NeighborhoodSetupScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  final bool returnAfterSave;
  const NeighborhoodSetupScreen({
    super.key,
    required this.profile,
    this.returnAfterSave = false,
  });

  @override
  ConsumerState<NeighborhoodSetupScreen> createState() =>
      _NeighborhoodSetupScreenState();
}

class _NeighborhoodSetupScreenState
    extends ConsumerState<NeighborhoodSetupScreen> {
  late final _address = TextEditingController(text: widget.profile.address);
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String? _message;
  int _request = 0;
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _address.text.trim();
    if (query.length < 2) return;
    final request = ++_request;
    setState(() {
      _searching = true;
      _selected = null;
      _results = [];
      _message = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            '/api/users/me/address-search',
            queryParameters: {'query': query},
          );
      if (!mounted || request != _request) return;
      setState(() {
        _results = (response.data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        if (_results.isEmpty) _message = '검색 결과가 없어요. 시·군·구와 도로명을 함께 입력해주세요.';
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _message = '주소 검색에 실패했어요. 다시 시도해주세요.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    final home = _selected;
    if (home == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('검색 결과에서 집주소를 선택해주세요')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(dioProvider)
          .put(
            '/api/users/me/neighborhood',
            data: {
              'address': home['address'],
              'lat': home['lat'],
              'lng': home['lng'],
            },
          );
      ref.invalidate(userProfileProvider);
      if (mounted && widget.returnAfterSave) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 동네 저장에 실패했어요. 다시 시도해주세요')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('내 동네 설정')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _address,
                  maxLength: 100,
                  onChanged: (_) {
                    ++_request;
                    setState(() {
                      _selected = null;
                      _results = [];
                      _searching = false;
                      _message = null;
                    });
                  },
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: '집주소 검색',
                    hintText: '시·군·구와 도로명 또는 지번을 입력해주세요',
                  ),
                ),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: Text(_searching ? '검색 중…' : '주소 검색'),
                ),
                const SizedBox(height: 12),
                const Text('검색 결과에서 주소를 선택해주세요. 집 주변 2km를 내 동네로 사용해요.'),
                if (_message != null) Text(_message!),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  title: Text(result['address'] as String),
                  selected: identical(result, _selected),
                  trailing: identical(result, _selected)
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: _saving
                      ? null
                      : () => setState(() => _selected = result),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving || _selected == null ? null : _save,
                child: Text(_saving ? '저장 중…' : '이 주소로 내 동네 설정'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
