import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/core/constants/strings.dart';
import 'package:vit_mess/core/theme/app_theme.dart';
import 'package:vit_mess/models/menu.dart';
import 'package:vit_mess/widgets/stale_menu_dialog.dart';

import 'excel_helpers.dart';

void main() {
  group('Menu.isBeforeMonthOf', () {
    final august = menuForMonth('2026-08');

    test('is false for the month currently running', () {
      expect(august.isBeforeMonthOf(DateTime(2026, 8, 1)), isFalse);
      expect(august.isBeforeMonthOf(DateTime(2026, 8, 31, 23, 59)), isFalse);
    });

    test('is true once the month has ended', () {
      expect(august.isBeforeMonthOf(DateTime(2026, 9, 1)), isTrue);
      expect(august.isBeforeMonthOf(DateTime(2027, 1, 1)), isTrue);
    });

    test('is false for a month still to come', () {
      // Next month's spreadsheet arrives before the month starts, and must
      // import without a warning.
      expect(august.isBeforeMonthOf(DateTime(2026, 7, 30)), isFalse);
    });

    test('compares across a year boundary, not just the month number', () {
      final december = menuForMonth('2025-12');
      expect(december.isBeforeMonthOf(DateTime(2026, 1, 2)), isTrue);

      final january = menuForMonth('2027-01');
      expect(january.isBeforeMonthOf(DateTime(2026, 12, 2)), isFalse);
    });
  });

  group('StaleMenuImport', () {
    test('knows whether anything would be lost', () {
      expect(
        const StaleMenuImport(month: '2026-08').replacesExistingMenu,
        isFalse,
      );
      expect(
        const StaleMenuImport(
          month: '2026-08',
          currentMonth: '2026-09',
        ).replacesExistingMenu,
        isTrue,
      );
    });
  });

  group('confirmStaleMenuImport', () {
    /// Opens the dialog and reports what it answered.
    Future<bool?> showFor(
      WidgetTester tester,
      StaleMenuImport candidate, {
      ThemeData? theme,
    }) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    answer = await confirmStaleMenuImport(context, candidate),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('names both months so the cost is explicit', (tester) async {
      await showFor(
        tester,
        const StaleMenuImport(month: '2026-08', currentMonth: '2026-09'),
      );

      expect(find.text(Strings.staleImportTitle), findsOneWidget);
      expect(
        find.textContaining('August 2026', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('September 2026', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(Strings.staleImportCancel), findsOneWidget);
    });

    testWidgets('offers a different way out when nothing is cached', (
      tester,
    ) async {
      await showFor(tester, const StaleMenuImport(month: '2026-08'));

      // There is no menu to keep, so "Keep current menu" would be a lie.
      expect(find.text(Strings.staleImportCancel), findsNothing);
      expect(find.text(Strings.staleImportDismiss), findsOneWidget);
    });

    testWidgets('keeping the current menu answers no', (tester) async {
      var answer = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => answer = await confirmStaleMenuImport(
                  context,
                  const StaleMenuImport(
                    month: '2026-08',
                    currentMonth: '2026-09',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Strings.staleImportCancel));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });

    testWidgets('importing anyway answers yes', (tester) async {
      var answer = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => answer = await confirmStaleMenuImport(
                  context,
                  const StaleMenuImport(month: '2026-08'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Strings.staleImportAccept));
      await tester.pumpAndSettle();

      expect(answer, isTrue);
    });

    testWidgets('a dismissed dialog means no, not yes', (tester) async {
      var answer = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => answer = await confirmStaleMenuImport(
                  context,
                  const StaleMenuImport(month: '2026-08'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tapping the barrier is the same as walking away, and the safe answer
      // is the one a student gets by doing nothing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });

    testWidgets('renders in light mode too', (tester) async {
      await showFor(
        tester,
        const StaleMenuImport(month: '2026-08', currentMonth: '2026-09'),
        theme: AppTheme.light(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(Strings.staleImportTitle), findsOneWidget);
    });
  });
}
