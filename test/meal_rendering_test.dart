import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vit_mess/core/theme/app_theme.dart';
import 'package:vit_mess/models/meal.dart';
import 'package:vit_mess/models/meal_item.dart';
import 'package:vit_mess/models/meal_status.dart';
import 'package:vit_mess/models/menu_day.dart';
import 'package:vit_mess/viewmodels/meal_presentation.dart';
import 'package:vit_mess/widgets/meal_card.dart';
import 'package:vit_mess/widgets/meal_item_tile.dart';
import 'package:vit_mess/widgets/variant_pair_tile.dart';

Meal mealWith(List<MealItem> items) => Meal(
  type: MealType.lunch,
  startTime: const MinuteOfDay(12, 0),
  endTime: const MinuteOfDay(14, 30),
  items: items,
);

List<MealItem> plainItems(int count) => List<MealItem>.generate(
  count,
  (i) => MealItem(name: 'Dish ${i + 1}'),
);

MealPresentation presentationFor(
  Meal meal, {
  MealStatus status = MealStatus.upcoming,
}) => MealPresentation(
  meal: meal,
  day: MenuDay(date: DateTime(2026, 8, 17), weekday: 'Mon', meals: <Meal>[meal]),
  status: status,
);

Widget wrap(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  setUpAll(() {
    // Keep widget tests off the network; Google Fonts falls back locally.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('item-count extremes', () {
    testWidgets('renders a 3-item meal without overflow', (tester) async {
      final meal = mealWith(plainItems(3));
      await tester.pumpWidget(
        wrap(MealCard(presentation: presentationFor(meal), initiallyExpanded: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dish 1'), findsOneWidget);
      expect(find.text('Dish 3'), findsOneWidget);
      expect(find.textContaining('3 items'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a 13-item meal without overflow', (tester) async {
      final meal = mealWith(plainItems(13));
      await tester.pumpWidget(
        wrap(MealCard(presentation: presentationFor(meal), initiallyExpanded: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dish 1'), findsOneWidget);
      expect(find.text('Dish 13'), findsOneWidget);
      expect(find.textContaining('13 items'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a large system text scale', (tester) async {
      final meal = mealWith(plainItems(13));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: wrap(
            MealCard(
              presentation: presentationFor(meal),
              initiallyExpanded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('paired alternatives', () {
    final pairedMeal = mealWith(<MealItem>[
      const MealItem(name: 'Steamed Rice'),
      const MealItem(name: 'Chicken Curry', variant: ItemVariant.nonVeg),
      const MealItem(name: 'Paneer Butter Masala', variant: ItemVariant.veg),
      const MealItem(name: 'Curd'),
    ]);

    testWidgets('renders a pair as one tile, not two loose rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(MealItemsList(items: pairedMeal.items, animate: false)),
      );
      await tester.pumpAndSettle();

      // One combined tile for the pair...
      expect(find.byType(VariantPairTile), findsOneWidget);
      // ...carrying the "or" divider that marks it as a single choice.
      expect(find.text('or'), findsOneWidget);
    });

    testWidgets('shows each paired dish exactly once', (tester) async {
      await tester.pumpWidget(
        wrap(MealItemsList(items: pairedMeal.items, animate: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chicken Curry'), findsOneWidget);
      expect(find.text('Paneer Butter Masala'), findsOneWidget);
      expect(find.text('Steamed Rice'), findsOneWidget);
      expect(find.text('Curd'), findsOneWidget);
    });

    testWidgets('keeps pairs in their printed position', (tester) async {
      await tester.pumpWidget(
        wrap(MealItemsList(items: pairedMeal.items, animate: false)),
      );
      await tester.pumpAndSettle();

      final rice = tester.getTopLeft(find.text('Steamed Rice')).dy;
      final chicken = tester.getTopLeft(find.text('Chicken Curry')).dy;
      final curd = tester.getTopLeft(find.text('Curd')).dy;

      expect(rice, lessThan(chicken));
      expect(chicken, lessThan(curd));
    });

    testWidgets('degrades an orphaned half-pair to a plain row', (
      tester,
    ) async {
      // A truncated document can leave a variant item without its partner.
      final meal = mealWith(<MealItem>[
        const MealItem(name: 'Rice'),
        const MealItem(name: 'Fish Fry', variant: ItemVariant.nonVeg),
      ]);
      await tester.pumpWidget(
        wrap(MealItemsList(items: meal.items, animate: false)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VariantPairTile), findsNothing);
      expect(find.text('Fish Fry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every item carries a variant mark', (tester) async {
      await tester.pumpWidget(
        wrap(MealItemsList(items: pairedMeal.items, animate: false)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VariantMark), findsNWidgets(4));
    });
  });

  group('meal state', () {
    testWidgets('collapses and expands on tap', (tester) async {
      final meal = mealWith(plainItems(4));
      await tester.pumpWidget(wrap(MealCard(presentation: presentationFor(meal))));
      await tester.pumpAndSettle();

      expect(find.text('Dish 1'), findsNothing);

      await tester.tap(find.byType(MealCard));
      await tester.pumpAndSettle();

      expect(find.text('Dish 1'), findsOneWidget);
    });

    testWidgets('renders in light mode without error', (tester) async {
      final meal = mealWith(plainItems(6));
      await tester.pumpWidget(
        wrap(
          MealCard(presentation: presentationFor(meal), initiallyExpanded: true),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders each status without error', (tester) async {
      for (final status in MealStatus.values) {
        final meal = mealWith(plainItems(5));
        await tester.pumpWidget(
          wrap(
            MealCard(
              presentation: presentationFor(meal, status: status),
              initiallyExpanded: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'status: $status');
      }
    });
  });

  group('Special plan lists alternatives separately', () {
    final pairedMeal = mealWith(<MealItem>[
      const MealItem(name: 'Steamed Rice'),
      const MealItem(name: 'Masala Onion Omlet', variant: ItemVariant.nonVeg),
      const MealItem(name: 'Boiled Chick Peas Salad', variant: ItemVariant.veg),
    ]);

    testWidgets('drops the "or" grouping when pairing is off', (tester) async {
      await tester.pumpWidget(
        wrap(
          MealItemsList(
            items: pairedMeal.items,
            animate: false,
            pairAlternatives: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Special plan serves both, so there is no either/or tile.
      expect(find.byType(VariantPairTile), findsNothing);
      expect(find.text('or'), findsNothing);

      // Both dishes still appear, still marked.
      expect(find.text('Masala Onion Omlet'), findsOneWidget);
      expect(find.text('Boiled Chick Peas Salad'), findsOneWidget);
      expect(find.byType(VariantMark), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('still pairs on the Veg & Non-Veg plan', (tester) async {
      await tester.pumpWidget(
        wrap(MealItemsList(items: pairedMeal.items, animate: false)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VariantPairTile), findsOneWidget);
      expect(find.text('or'), findsOneWidget);
    });
  });
}
