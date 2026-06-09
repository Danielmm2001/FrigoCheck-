import 'package:flutter_test/flutter_test.dart';
import 'package:frigocheck/app.dart';

void main() {
  testWidgets('FrigoCheck renders onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const FrigoCheckApp());

    expect(find.text('FrigoCheck'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);
  });
}
