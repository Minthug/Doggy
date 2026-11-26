import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doggy/features/home/presentation/widgets/app_intro_gate.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app(int id, VoidCallback ready) => ProviderScope(
    child: MaterialApp(
      home: AppIntroGate(
        key: ValueKey(id),
        userId: id,
        onReady: ready,
        child: const Scaffold(body: Text('홈')),
      ),
    ),
  );

  testWidgets('확인한 계정에는 반복하지 않고 다른 계정에는 안내한다', (tester) async {
    var ready = 0;
    await tester.pumpWidget(app(1, () => ready++));
    await tester.pumpAndSettle();
    expect(find.text('Doggy, 이렇게 사용해요'), findsOneWidget);
    expect(ready, 0);
    expect(find.text('홈 · 오늘의 산책을 준비해요'), findsOneWidget);
    expect(find.text('지도 · 산책하고 흔적을 찾아요'), findsOneWidget);
    expect(find.text('커뮤니티 · 보호자들과 나눠요'), findsOneWidget);
    await tester.tap(find.text('알겠어요, 시작할게요'));
    await tester.pumpAndSettle();
    expect(ready, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(1, () => ready++));
    await tester.pumpAndSettle();
    expect(find.byType(AppIntroDialog), findsNothing);
    expect(ready, 2);
    await tester.pumpWidget(app(2, () => ready++));
    await tester.pumpAndSettle();
    expect(find.byType(AppIntroDialog), findsOneWidget);
  });

  testWidgets('작은 화면과 큰 글꼴에서도 스크롤하고 시작할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: AppIntroGate(userId: 3, child: const Scaffold()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('알겠어요, 시작할게요'));
    await tester.pumpAndSettle();
    expect(find.byType(AppIntroDialog), findsNothing);
  });
}
