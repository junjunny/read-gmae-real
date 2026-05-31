// 기본 스모크 테스트. Firebase 초기화가 필요한 GrimPingPongApp 대신
// 순수 위젯 단위 테스트로 확장하는 것을 권장.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a basic MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('그림핑퐁'))),
    );
    expect(find.text('그림핑퐁'), findsOneWidget);
  });
}
