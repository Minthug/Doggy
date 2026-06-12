import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../models/household_model.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository(ref.watch(dioProvider));
});

class HouseholdRepository {
  final Dio _dio;

  HouseholdRepository(this._dio);

  Future<Household> create(String name) async {
    final response = await _dio.post('/api/households', data: {'name': name});
    return Household.fromJson(response.data);
  }

  Future<Household> getMyHousehold() async {
    final response = await _dio.get('/api/households/me');
    return Household.fromJson(response.data);
  }

  Future<Household> join(String inviteCode) async {
    final response = await _dio.post('/api/households/join', data: {'inviteCode': inviteCode});
    return Household.fromJson(response.data);
  }

  Future<String> refreshInviteCode() async {
    final response = await _dio.post('/api/households/invite-code/refresh');
    return response.data['inviteCode'] as String;
  }

  Future<void> leave() async {
    await _dio.delete('/api/households/leave');
  }
}
