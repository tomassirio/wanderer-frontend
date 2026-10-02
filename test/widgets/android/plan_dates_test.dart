import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';

void main() {
  testWidgets('single-day plans pick one date; end equals start',
      (tester) async {
    ({DateTime start, DateTime end, bool multiDay})? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await pickPlanDates(context, multiDay: false),
          child: const Text('pick'),
        ),
      ),
    ));
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    // A single-date picker, not a range one.
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked!.multiDay, isFalse);
    expect(picked!.end, picked!.start);
  });
}
