import 'package:flutter_test/flutter_test.dart';
import 'package:vit_mess/core/utils/dish_classifier.dart';
import 'package:vit_mess/models/meal_item.dart';

void main() {
  group('non-veg dishes', () {
    test('catches the meats a mess board actually writes', () {
      for (final name in <String>[
        'Telangana Chicken Curry',
        'Chicken Dum Biryani',
        'Pepper Chicken',
        'Mutton Kheema',
        'Fish Fry',
        'Prawn Masala',
        'Egg Bhurji',
        'Scrambled Egg',
        'Boiled Egg',
        'Egg Masala',
      ]) {
        expect(
          classifyDishName(name),
          DishHighlight.nonVeg,
          reason: name,
        );
      }
    });

    test('wins when a dish names both options', () {
      // "Chicken Dum Biryani/Vegetable Dum Biryani" is one line on the board;
      // whoever takes it is being served non-veg.
      expect(
        classifyDishName('Chicken Dum Biryani/Vegetable Dum Biryani'),
        DishHighlight.nonVeg,
      );
    });
  });

  group('highlighted vegetarian dishes', () {
    test('catches the marquee veg dishes', () {
      for (final name in <String>[
        'Achari Paneer',
        'Paneer Butter Masala',
        'Mushroom Biryani',
        'Pepper Mushroom',
        'Chole Soya Chunks Curry',
        'Rajma Masala',
        'Veg Kofta Curry',
        'Gobi Manchurian',
        'Lobia Masala',
      ]) {
        expect(classifyDishName(name), DishHighlight.veg, reason: name);
      }
    });
  });

  group('everyday staples stay neutral', () {
    test('rice, dal and drinks are not highlighted', () {
      for (final name in <String>[
        'White Rice',
        'Mudda Pappu',
        'Beetroot Tomato Rasam',
        'Tea/Coffee/Milk',
        'Coconut Chutney',
        'Thick Curd',
        'Papad',
        'Pulka',
        'Carrot Idly',
        'Masala Ghee Roast Dosa',
        'Muskmelon Cut Fruit',
      ]) {
        expect(classifyDishName(name), DishHighlight.none, reason: name);
      }
    });

    test('matches whole words only', () {
      // A substring match would wrongly flag these.
      expect(classifyDishName('Eggless Cake'), DishHighlight.none);
      expect(classifyDishName('Beans Poriyal'), DishHighlight.none);
      expect(classifyDishName('Meatless Monday Special'), DishHighlight.none);
    });

    test('is case and punctuation insensitive', () {
      expect(classifyDishName('CHICKEN 65'), DishHighlight.nonVeg);
      expect(classifyDishName('paneer tikka'), DishHighlight.veg);
    });

    test('handles an empty name', () {
      expect(classifyDishName(''), DishHighlight.none);
    });
  });

  group('MealItem.highlight', () {
    test('an explicit sheet marker always wins', () {
      // The sheet said veg, so it is veg even though the name says otherwise.
      const tagged = MealItem(
        name: 'Chicken Style Soya',
        variant: ItemVariant.veg,
      );
      expect(tagged.highlight, DishHighlight.veg);

      const nonVeg = MealItem(name: 'Mystery Curry', variant: ItemVariant.nonVeg);
      expect(nonVeg.highlight, DishHighlight.nonVeg);
    });

    test('falls back to the name when the sheet tagged nothing', () {
      expect(
        const MealItem(name: 'Telangana Chicken Curry').highlight,
        DishHighlight.nonVeg,
      );
      expect(
        const MealItem(name: 'Achari Paneer').highlight,
        DishHighlight.veg,
      );
      expect(const MealItem(name: 'White Rice').highlight, DishHighlight.none);
    });

    test('isHighlighted marks only the two saturated states', () {
      expect(DishHighlight.none.isHighlighted, isFalse);
      expect(DishHighlight.veg.isHighlighted, isTrue);
      expect(DishHighlight.nonVeg.isHighlighted, isTrue);
    });
  });
}
