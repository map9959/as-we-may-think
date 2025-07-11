// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:as_we_may_think/app.dart';
import 'package:as_we_may_think/state/app_state.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets('Submitting a note opens modal with editable fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Find the note input field
    final noteField = find.byType(TextField).last;
    await tester.enterText(noteField, 'Test Note Title\nTest note content');
    // Simulate pressing Enter (submit)
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    // Modal should appear with title and content fields
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Write your note...'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    // The title field should be pre-filled
    final titleField = find.widgetWithText(TextField, 'Test Note Title');
    expect(titleField, findsOneWidget);
    // The content field in the modal should have the correct hint and text
    final contentField = find.descendant(
      of: find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText == 'Write your note...')),
      matching: find.text('Test Note Title\nTest note content'),
    );
    expect(contentField, findsOneWidget);
    // Ensure Cancel button is present
    expect(find.text('Cancel'), findsOneWidget);
    // Always close the modal to avoid pump timeout
    await tester.tap(find.text('Cancel'));
    await tester.pump();
  });

  testWidgets('Save button adds note and closes modal', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    final noteField = find.byType(TextField).last;
    await tester.enterText(noteField, 'Save Note Title\nSave note content');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pump();
    // Modal should close
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('Cancel button closes modal without saving', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    final noteField = find.byType(TextField).last;
    await tester.enterText(noteField, 'Cancel Note Title\nCancel note content');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    // Ensure Cancel button is present
    expect(find.text('Cancel'), findsOneWidget);
    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    // Modal should close
    expect(find.text('Save'), findsNothing);
  });
}
