import 'package:flutter_test/flutter_test.dart';
import 'package:wooden_staff_app/main.dart';

void main() {
  testWidgets('Staff app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WoodenStaffApp());
    expect(find.text('WoodCraft'), findsOneWidget);
  });
}
