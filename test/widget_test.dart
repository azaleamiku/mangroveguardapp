import 'package:flutter_test/flutter_test.dart';
import 'package:mangroveguardapp/main.dart';

void main() {
  testWidgets('Onboarding page renders first step', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MangroveGuardApp(showHome: false));

    expect(find.text('Data Privacy & Terms'), findsOneWidget);
    expect(find.text('I ACCEPT & GET STARTED'), findsNothing);
  });
}
