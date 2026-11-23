import 'package:flutter_test/flutter_test.dart';
import 'package:wooden_customer_app/main.dart';

void main() {
  testWidgets('Customer app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WoodenCustomerApp());
    expect(find.text('WoodCraft'), findsOneWidget);
  });
}
