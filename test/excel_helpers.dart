import 'package:excel/excel.dart';

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
