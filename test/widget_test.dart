import 'package:flutter_test/flutter_test.dart';
import 'package:bichito_widget/main.dart';

void main() {
  testWidgets('App renders bichito widget', (tester) async {
    await tester.pumpWidget(const BichitoApp());
    expect(find.byType(BichitoApp), findsOneWidget);
  });
}
