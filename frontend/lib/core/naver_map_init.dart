import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'secrets.dart';

Future<void> initNaverMap() async {
  await FlutterNaverMap().init(clientId: naverMapClientId);
}
