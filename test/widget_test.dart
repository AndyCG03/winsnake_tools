import 'package:flutter_test/flutter_test.dart';
import 'package:winsnake_tools/main.dart';

void main() {
  testWidgets('App renders winsnake widget', (tester) async {
    await tester.pumpWidget(const WinSnakeApp());
    expect(find.byType(WinSnakeApp), findsOneWidget);
  });
}
