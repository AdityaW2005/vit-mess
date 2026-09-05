import 'package:excel/excel.dart';
import 'package:vit_mess/core/config/app_config.dart';
import 'package:vit_mess/models/menu.dart';
import 'package:vit_mess/models/mess.dart';

/// A menu that carries nothing but the month it covers.
///
/// Enough for the month-comparison rules, which never look at the days.
Menu menuForMonth(String month) => Menu(
  schemaVersion: AppConfig.supportedSchemaVersion,
  month: month,
  campus: AppConfig.campus,
  messes: const <Mess>[],
);

/// Builds a real `.xlsx` in memory from rows of plain strings.
///
/// Tests parse genuine workbook bytes rather than a hand-made stand-in, so the
/// decoding path is exercised end to end.
List<int> buildWorkbook(Map<String, List<List<String>>> sheets) {
  final workbook = Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet();

  for (final entry in sheets.entries) {
    final sheet = workbook[entry.key];
    for (var row = 0; row < entry.value.length; row++) {
      final cells = entry.value[row];
      for (var column = 0; column < cells.length; column++) {
        final text = cells[column];
        if (text.isEmpty) continue;
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
          TextCellValue(text),
        );
      }
    }
  }

  // createExcel seeds an empty "Sheet1"; drop it unless the test wanted it.
  if (defaultSheet != null && !sheets.containsKey(defaultSheet)) {
    workbook.delete(defaultSheet);
  }

  final bytes = workbook.encode();
  if (bytes == null) throw StateError('Could not encode the test workbook');
  return bytes;
}

/// A grid-layout sheet: one row per day, a column per meal.
List<List<String>> gridSheet() => <List<String>>[
  <String>['Date', 'Breakfast', 'Lunch', 'Snacks', 'Dinner'],
  <String>[
    '2026-08-17',
    'Carrot Idly, Medhu Vada',
    'Steamed Rice, Chicken Curry (non-veg), Paneer Butter Masala (veg)',
    'Masala Tea',
    'Chapathi, Dal Tadka',
  ],
  <String>[
    '2026-08-18',
    'Masala Dosa',
    'Sambar Rice',
    'Onion Bajji',
    'Veg Fried Rice',
  ],
];

/// A rotation sheet in the shape the VIT-AP mess office publishes: a title
/// row, a `Day` column whose first cell carries the weekday plus the dates
/// that repeat it (the remaining rows are blank, exactly as a merged cell
/// reads), and a block of service instructions after the last day.
List<List<String>> rotationSheet() => <List<String>>[
  <String>['VEG & NON-VEG MESS MENU FOR THE MONTH OF AUGUST'],
  <String>['Day', 'Breakfast', 'Lunch', 'Snacks', 'Dinner'],
  <String>[
    'Sat\n1, 15, 29',
    'Masala Ghee Roast Dosa',
    'Carrot & Cucumber Salad',
    'Punugulu 10 Pcs Std Size',
    'Beetroot & Carrot Salad',
  ],
  <String>['', 'Vada Pav', 'White Rice', 'Ginger Tea/Coffee/Milk', 'Mango Dal'],
  <String>['', 'Tea/Coffee/Milk', 'Mudda Pappu', '', 'Thick Curd'],
  <String>[],
  <String>[
    'Sun\n2, 16, 30',
    'Shavige Bath',
    'Chicken Dum Biryani/Vegetable Dum Biryani',
    'Dahi Puri (8 Pcs)',
    'Ragi Idly',
  ],
  <String>['', 'Coconut Chutney', 'Onion Raitha', 'Onions', 'Dondakaya Fry'],
  <String>[],
  <String>[
    'Mon\n3, 17, 31',
    'Carrot Idly',
    'Chapathi',
    'Dry Maggi',
    'Onions & Lemon Salad',
  ],
  <String>[
    '',
    'Chole Curry',
    'Palak Dal',
    'Tomato Sauce',
    'Telangana Chicken Curry (Non-Veg)',
  ],
  <String>['', 'Tea/Coffee/Milk', 'Tomato Rice', '', 'Achari Paneer (Veg)'],
  <String>[],
  <String>[],
  <String>['', 'MESS SERVICE INSTRUCTIONS'],
  <String>['', '1. Thick curd must be served as per the menu.'],
];

/// A long-layout sheet: one row per dish.
List<List<String>> longSheet() => <List<String>>[
  <String>['Date', 'Meal', 'Item', 'Variant'],
  <String>['2026-08-17', 'Breakfast', 'Carrot Idly', ''],
  <String>['2026-08-17', 'Breakfast', 'Medhu Vada', ''],
  <String>['2026-08-17', 'Lunch', 'Steamed Rice', ''],
  <String>['2026-08-17', 'Lunch', 'Chicken Curry', 'nonveg'],
  <String>['2026-08-17', 'Lunch', 'Paneer Butter Masala', 'veg'],
  <String>['2026-08-17', 'Snacks', 'Masala Tea', ''],
  <String>['2026-08-17', 'Dinner', 'Chapathi', ''],
];
