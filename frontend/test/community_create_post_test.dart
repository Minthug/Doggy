import 'package:doggy/features/community/presentation/screens/create_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('글쓰기 화면은 기본 카테고리를 선택하지 않는다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePostScreen())),
    );

    expect(find.text('분양/입양'), findsOneWidget);
    expect(find.text('카테고리를 선택해 주세요'), findsNothing);

    await tester.tap(find.text('등록'));
    await tester.pump();

    expect(find.text('카테고리를 선택해 주세요'), findsOneWidget);
  });
}
