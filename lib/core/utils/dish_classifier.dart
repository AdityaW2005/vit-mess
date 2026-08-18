/// How prominently a dish should be marked in the menu.
///
/// A mess menu is mostly staples — rice, dal, chutney, tea. What a student
/// scans for is the one dish that decides the meal: is there chicken tonight,
/// or is it paneer? Those get a saturated marker; everything else stays quiet,
/// so the highlight actually means something.
enum DishHighlight {
  /// An everyday item. Neutral marker.
  none,

  /// A marquee vegetarian dish — paneer, mushroom, soya and friends.
  veg,

  /// A non-vegetarian dish.
  nonVeg;

  /// True when this dish should be visually lifted out of the list.
  bool get isHighlighted => this != DishHighlight.none;
}

/// Classifies a dish from its name alone.
///
/// Pure and deterministic, so it is unit tested rather than eyeballed. Callers
/// that know the sheet's explicit veg/non-veg marker should trust that first —
/// see `MealItem.highlight`.
///
/// Matching is word-boundary aware: "Egg Bhurji" is non-veg, but "Eggless
/// Cake" and "Beans Poriyal" are not caught by `egg` or `bean`.
DishHighlight classifyDishName(String name) {
  final text = name.toLowerCase();

  // Non-veg wins outright: a dish naming both ("Chicken Biryani / Veg
  // Biryani") is still a non-veg serving for whoever takes it.
  for (final keyword in _nonVegKeywords) {
    if (_containsWord(text, keyword)) return DishHighlight.nonVeg;
  }
  for (final keyword in _vegKeywords) {
    if (_containsWord(text, keyword)) return DishHighlight.veg;
  }
  return DishHighlight.none;
}

/// True when [keyword] appears in [text] as a whole word.
bool _containsWord(String text, String keyword) {
  var index = text.indexOf(keyword);
  while (index != -1) {
    final beforeOk = index == 0 || !_isWordChar(text.codeUnitAt(index - 1));
    final endIndex = index + keyword.length;
    final afterOk =
        endIndex >= text.length || !_isWordChar(text.codeUnitAt(endIndex));
    if (beforeOk && afterOk) return true;
    index = text.indexOf(keyword, index + 1);
  }
  return false;
}

bool _isWordChar(int codeUnit) =>
    (codeUnit >= 97 && codeUnit <= 122) || // a-z
    (codeUnit >= 65 && codeUnit <= 90) || // A-Z
    (codeUnit >= 48 && codeUnit <= 57); // 0-9

/// Meat, fish and egg. Ordered roughly by how often they appear on the board.
const List<String> _nonVegKeywords = <String>[
  'chicken',
  'egg',
  'eggs',
  'mutton',
  'fish',
  'prawn',
  'prawns',
  'meat',
  'keema',
  'kheema',
  'lamb',
  'crab',
  'omelette',
  'omlette',
  'bhurji', // only ever written of egg on a mess board
  'chettinad chicken',
  'non-veg',
  'nonveg',
];

/// The vegetarian dishes worth calling out: protein and centrepiece curries,
/// not the rice and rasam that appear every single day.
const List<String> _vegKeywords = <String>[
  'paneer',
  'mushroom',
  'soya',
  'tofu',
  'kofta',
  'chole',
  'channa',
  'chana',
  'rajma',
  'lobia',
  'manchurian',
  'malai',
  'kadai veg',
  'veg biryani',
  'vegetable biryani',
  'veg dum biryani',
  'mushroom biryani',
];
