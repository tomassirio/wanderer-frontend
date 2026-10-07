import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/common/legal_document.dart';

void main() {
  Future<void> open(WidgetTester tester, Size size, LegalDocument doc) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showLegalDocument(context, doc),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    // The document is a real asset load: let it finish outside fake time.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  testWidgets('wide screens get a popup window', (tester) async {
    await open(tester, const Size(1440, 1000), LegalDocument.terms);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('phones get a bottom sheet', (tester) async {
    await open(tester, const Size(400, 800), LegalDocument.privacy);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });
}
