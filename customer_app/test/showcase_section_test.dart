import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wooden_customer_app/widgets/suresh_timbers_showcase.dart';

void main() {
  testWidgets('SureshTimbersShowcaseSection renders only kept showcase sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SureshTimbersShowcaseSection(),
          ),
        ),
      ),
    );

    // Kept sections
    expect(find.text('Signature Royal Creations'), findsOneWidget);
    expect(find.text('Certifications & Standards'), findsOneWidget);

    // Removed sections
    expect(find.text('Our Achievements & Legacy'), findsNothing);
    expect(find.text('Proud Milestones & Guarantees'), findsNothing);
    expect(find.text('Strength Behind Every Door'), findsNothing);
    expect(find.text('Trusted by Iconic Institutions'), findsNothing);
    expect(find.text('Book a Free Royal Design Consultation'), findsNothing);
  });
}
