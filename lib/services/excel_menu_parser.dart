import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/meal.dart';
import '../models/meal_item.dart';
import '../models/menu.dart';
import '../models/menu_day.dart';
import '../models/mess.dart';

/// Raised when a workbook could not be turned into a menu.
class ExcelParseException implements Exception {
  /// Creates an exception describing why parsing failed.
  const ExcelParseException(this.message, {this.cause});

  /// Technical description, for logs only.
  final String message;

  /// The underlying error, if any.
  final Object? cause;

  @override
  String toString() => 'ExcelParseException($message)';
}

/// Turns a mess-menu spreadsheet into the app's [Menu] model.
///
/// Pure translation — no disk, no network. Three layouts are recognised,
/// chosen per sheet by inspecting the header row, because real mess menus
/// arrive in all of them.
///
/// **Rotation** — the shape the VIT-AP mess office publishes. A `Day` column
/// holds a weekday and the dates of the month that repeat it, and each meal
/// column lists one dish per row underneath:
///
/// | Day | Breakfast | Lunch | Snacks | Dinner |
/// |-----|-----------|-------|--------|--------|
/// | Sat<br>1, 15, 29 | Masala Dosa | Carrot Salad | Punugulu | Roti |
/// |  | Vada Pav | Pulka | Chutney | White Rice |
///
/// **Grid** — one row per day, keyed by an explicit date:
///
/// | Date | Breakfast | Lunch | Snacks | Dinner |
/// |------|-----------|-------|--------|--------|
/// | 2026-08-17 | Carrot Idly, Vada | Rice, Chicken Curry (non-veg) | Tea | Chapathi |
///
/// **Long** — one row per dish:
///
/// | Date | Meal | Item | Variant |
/// |------|------|------|---------|
/// | 2026-08-17 | Lunch | Chicken Curry | nonveg |
///
/// Each **worksheet is one subscription tier**; the sheet name becomes the
/// tier name. A `Mess` / `Plan` / `Tier` column, when present, overrides that.
///
/// Serving windows are not read from the sheet — they come from [MealType]'s
/// canonical windows and remain overridable in Settings.
class ExcelMenuParser {
  /// Creates a parser.
  const ExcelMenuParser();

  /// Parses [bytes] (the contents of an `.xlsx`) into a [Menu].
  ///
  /// Throws [ExcelParseException] when the workbook yields no usable day.
  Menu parse(List<int> bytes, {DateTime? now}) {
    Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } on Object catch (error) {
      throw ExcelParseException('Workbook could not be opened', cause: error);
    }

    if (workbook.tables.isEmpty) {
      throw const ExcelParseException('Workbook has no sheets');
    }

    final moment = now ?? DateTime.now();
    final tiers = <String, _TierBuilder>{};

    for (final entry in workbook.tables.entries) {
      final sheetName = entry.key;
      final rows = entry.value.rows;
      if (rows.isEmpty) continue;

      try {
        _parseSheet(
          sheetName: sheetName,
          rows: rows,
          tiers: tiers,
          now: moment,
        );
      } on Object catch (error) {
        // One unreadable sheet must not sink the whole import.
        debugPrint('Skipping sheet "$sheetName": $error');
      }
    }

    final messes = <Mess>[];
    for (final builder in tiers.values) {
      final mess = builder.build();
      if (mess != null) messes.add(mess);
    }

    if (messes.isEmpty) {
      throw const ExcelParseException(
        'No menu rows were found. The sheet needs a Day or Date column and a '
        'column per meal, or one row per dish.',
      );
    }

    return Menu(
      schemaVersion: AppConfig.supportedSchemaVersion,
      month: _inferMonth(messes),
      campus: AppConfig.campus,
      messes: messes,
    );
  }

  // ------------------------------------------------------------- per sheet

  void _parseSheet({
    required String sheetName,
    required List<List<Data?>> rows,
    required Map<String, _TierBuilder> tiers,
    required DateTime now,
  }) {
    final headerIndex = _findHeaderRow(rows);
    if (headerIndex == null) return;

    final header = rows[headerIndex]
        .map((cell) => _normalizeHeader(_cellText(cell)))
        .toList(growable: false);

    // A sheet may key its rows by an explicit date, or by a weekday that
    // repeats on several dates. Either becomes the row anchor.
    final dateColumn = _columnFor(header, const <String>['date', 'day date']);
    final dayColumn = _columnFor(header, const <String>[
      'day',
      'days',
      'weekday',
      'day of week',
    ]);
    final anchorColumn = dateColumn ?? dayColumn;
    if (anchorColumn == null) return;

    final itemColumn = _columnFor(header, const <String>[
      'item',
      'items',
      'dish',
      'dishes',
      'menu',
    ]);
    final mealColumn = _columnFor(header, const <String>[
      'meal',
      'mealtype',
      'meal type',
      'session',
    ]);

    // Long layout needs both a meal column and an item column; anything else
    // with recognisable meal-name headers is treated as a column-per-meal
    // sheet.
    if (itemColumn != null && mealColumn != null) {
      _parseLongRows(
        sheetName: sheetName,
        header: header,
        rows: rows.skip(headerIndex + 1),
        dateColumn: anchorColumn,
        mealColumn: mealColumn,
        itemColumn: itemColumn,
        tiers: tiers,
      );
      return;
    }

    _parseBlockRows(
      sheetName: sheetName,
      header: header,
      rows: rows,
      headerIndex: headerIndex,
      anchorColumn: anchorColumn,
      tiers: tiers,
      now: now,
    );
  }

  /// Reads a column-per-meal sheet, whether it is keyed by explicit dates or
  /// by a weekday that repeats across the month.
  ///
  /// Rows are gathered into *blocks*. A block opens on a row whose anchor cell
  /// names a date, a weekday, or a list of day numbers, and stays open while
  /// following rows keep adding dishes — which is how a merged `Day` cell
  /// spanning a dozen rows is handled. A wholly blank row closes the block, so
  /// trailing notes after the last day are never absorbed into it.
  void _parseBlockRows({
    required String sheetName,
    required List<String> header,
    required List<List<Data?>> rows,
    required int headerIndex,
    required int anchorColumn,
    required Map<String, _TierBuilder> tiers,
    required DateTime now,
  }) {
    final mealColumns = <int, MealType>{};
    for (var i = 0; i < header.length; i++) {
      if (i == anchorColumn) continue;
      final meal = MealType.fromJson(header[i]) ?? _mealFromLabel(header[i]);
      if (meal != null) mealColumns[i] = meal;
    }
    if (mealColumns.isEmpty) return;

    final tierColumn = _columnFor(header, const <String>[
      'mess',
      'plan',
      'tier',
      'subscription',
    ]);

    final blocks = <_Block>[];
    _Block? current;

    for (var r = headerIndex + 1; r < rows.length; r++) {
      final row = rows[r];

      // Everything below a "mess service instructions" style heading is prose,
      // not menu.
      if (_isTerminatorRow(row)) break;

      final anchorCell = _at(row, anchorColumn);
      final anchorText = _cellText(anchorCell);
      final hasDishes = mealColumns.keys.any(
        (column) => _cellText(_at(row, column)).trim().isNotEmpty,
      );

      final explicitDate = _cellDate(anchorCell);
      final marker = explicitDate == null ? _parseDayCell(anchorText) : null;

      if (explicitDate != null ||
          (marker != null && (marker.weekday != null || marker.days.isNotEmpty))) {
        current = _Block(
          explicitDate: explicitDate,
          weekday: marker?.weekday,
          dayNumbers: marker?.days ?? const <int>[],
          tierLabel: tierColumn == null
              ? sheetName
              : _firstNonEmpty(_cellText(_at(row, tierColumn)), sheetName),
        );
        blocks.add(current);
      } else if (!hasDishes) {
        // A blank row ends the block; a later row cannot rejoin it.
        current = null;
        continue;
      }

      if (current == null) continue;

      for (final entry in mealColumns.entries) {
        final cell = _cellText(_at(row, entry.key));
        if (cell.trim().isEmpty) continue;
        for (final parsed in _splitItems(cell)) {
          current.add(entry.value, MealItem(name: parsed.name, variant: parsed.variant));
        }
      }
    }

    if (blocks.isEmpty) return;

    final period = _resolvePeriod(
      rows: rows,
      headerIndex: headerIndex,
      blocks: blocks,
      now: now,
    );

    for (final block in blocks) {
      final builderId = _tierId(block.tierLabel);
      final builder = tiers.putIfAbsent(
        builderId,
        () => _TierBuilder(id: builderId, name: _tierName(block.tierLabel)),
      );
      for (final date in block.datesIn(period)) {
        block.meals.forEach((type, items) {
          for (final item in items) {
            builder.add(date: date, meal: type, item: item);
          }
        });
      }
    }
  }

  /// Works out which month the sheet covers.
  ///
  /// The title above the header usually names it ("...FOR THE MONTH OF
  /// AUGUST"). When it names no year — which is the norm — the year is
  /// recovered by checking which candidate makes the sheet's own weekday
  /// labels line up with its day numbers. That is exact: only one year in a
  /// six-year window puts 1, 15 and 29 August on a Saturday.
  _Period _resolvePeriod({
    required List<List<Data?>> rows,
    required int headerIndex,
    required List<_Block> blocks,
    required DateTime now,
  }) {
    final buffer = StringBuffer();
    for (var r = 0; r <= headerIndex && r < rows.length; r++) {
      for (final cell in rows[r]) {
        buffer
          ..write(' ')
          ..write(_cellText(cell));
      }
    }
    final title = buffer.toString().toLowerCase();

    final month = _monthFromText(title);
    if (month == null) return _Period(now.year, now.month);

    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(title);
    if (yearMatch != null) {
      return _Period(int.parse(yearMatch.group(1)!), month);
    }

    return _Period(_inferYear(month, blocks, now), month);
  }

  /// Picks the year whose calendar matches the weekday labels in the sheet.
  int _inferYear(int month, List<_Block> blocks, DateTime now) {
    // Ordered so the current year wins any tie, then the near future.
    final candidates = <int>[now.year, now.year + 1, now.year - 1, now.year + 2];

    var bestYear = now.year;
    var bestScore = -1;

    for (final year in candidates) {
      final lastDay = DateTime(year, month + 1, 0).day;
      var score = 0;
      for (final block in blocks) {
        final weekday = block.weekday;
        if (weekday == null) continue;
        for (final day in block.dayNumbers) {
          if (day < 1 || day > lastDay) continue;
          if (_weekdayAbbrev(DateTime(year, month, day)) == weekday) score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestYear = year;
      }
    }
    return bestYear;
  }

  /// Reads an anchor cell that names a weekday and/or day numbers, such as
  /// `Sat\n1, 15, 29`.
  _DayMarker? _parseDayCell(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final weekday = _weekdayFromText(text);
    // Only take numbers once a weekday is present, or when the cell is
    // nothing but numbers and separators — otherwise a dish name with a
    // quantity in it would look like a day marker.
    final numeric = RegExp(r'^[\d\s,;/&and\-]+$', caseSensitive: false)
        .hasMatch(text);
    final days = <int>[];
    if (weekday != null || numeric) {
      for (final match in RegExp(r'\d{1,2}').allMatches(text)) {
        final value = int.parse(match.group(0)!);
        if (value >= 1 && value <= 31) days.add(value);
      }
    }

    if (weekday == null && days.isEmpty) return null;
    return _DayMarker(weekday: weekday, days: days);
  }

  /// True when the row starts a block of prose rather than menu content.
  bool _isTerminatorRow(List<Data?> row) {
    for (final cell in row) {
      final text = _cellText(cell).trim().toLowerCase();
      if (text.isEmpty) continue;
      if (text.contains('instruction') ||
          text.startsWith('note') ||
          text.startsWith('n.b') ||
          text.contains('terms and condition')) {
        return true;
      }
    }
    return false;
  }

  String? _weekdayFromText(String raw) {
    final token = RegExp(
      r'^[^a-z]*([a-z]+)',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (token == null) return null;
    final word = token.group(1)!.toLowerCase();
    for (var i = 0; i < _weekdayLabels.length; i++) {
      final label = _weekdayLabels[i].toLowerCase();
      if (word == label || word == _weekdayFull[i]) return _weekdayLabels[i];
    }
    return null;
  }

  int? _monthFromText(String text) {
    for (var i = 0; i < _monthNames.length; i++) {
      if (RegExp('\\b${_monthNames[i]}', caseSensitive: false).hasMatch(text)) {
        return i + 1;
      }
    }
    return null;
  }

  static String _weekdayAbbrev(DateTime date) =>
      _weekdayLabels[date.weekday - 1];

  static const List<String> _weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _weekdayFull = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const List<String> _monthNames = <String>[
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  void _parseLongRows({
    required String sheetName,
    required List<String> header,
    required Iterable<List<Data?>> rows,
    required int dateColumn,
    required int mealColumn,
    required int itemColumn,
    required Map<String, _TierBuilder> tiers,
  }) {
    final variantColumn = _columnFor(header, const <String>[
      'variant',
      'type',
      'veg',
      'vegnonveg',
    ]);
    final tierColumn = _columnFor(header, const <String>[
      'mess',
      'plan',
      'tier',
      'subscription',
    ]);
    final startColumn = _columnFor(header, const <String>[
      'start',
      'starttime',
      'start time',
      'from',
    ]);
    final endColumn = _columnFor(header, const <String>[
      'end',
      'endtime',
      'end time',
      'to',
    ]);

    // A date typed once and left blank on following rows is normal in a
    // hand-kept sheet, so the last seen value carries down.
    DateTime? currentDate;
    MealType? currentMeal;

    for (final row in rows) {
      if (_isTerminatorRow(row)) break;

      final date = _cellDate(_at(row, dateColumn)) ?? currentDate;
      if (date == null) continue;
      currentDate = date;

      final meal =
          MealType.fromJson(_cellText(_at(row, mealColumn))) ??
          _mealFromLabel(_cellText(_at(row, mealColumn))) ??
          currentMeal;
      if (meal == null) continue;
      currentMeal = meal;

      final rawItem = _cellText(_at(row, itemColumn));
      if (rawItem.trim().isEmpty) continue;

      final tierLabel = tierColumn == null
          ? sheetName
          : _firstNonEmpty(_cellText(_at(row, tierColumn)), sheetName);
      final builder = tiers.putIfAbsent(
        _tierId(tierLabel),
        () => _TierBuilder(id: _tierId(tierLabel), name: _tierName(tierLabel)),
      );

      final explicitVariant = variantColumn == null
          ? null
          : ItemVariant.fromJson(_cellText(_at(row, variantColumn)));

      // A single cell may still hold several dishes even in a long sheet.
      for (final parsed in _splitItems(rawItem)) {
        builder.add(
          date: date,
          meal: meal,
          item: MealItem(
            name: parsed.name,
            variant: explicitVariant ?? parsed.variant,
          ),
          start: startColumn == null
              ? null
              : MinuteOfDay.tryParse(_cellText(_at(row, startColumn))),
          end: endColumn == null
              ? null
              : MinuteOfDay.tryParse(_cellText(_at(row, endColumn))),
        );
      }
    }
  }

  // ------------------------------------------------------------- utilities

  /// The first row that looks like a header, i.e. carries a date or day
  /// column.
  ///
  /// Sheets often start with a title or a blank row or two, so the header is
  /// searched for rather than assumed to be row 1.
  int? _findHeaderRow(List<List<Data?>> rows) {
    final limit = rows.length < 15 ? rows.length : 15;
    for (var i = 0; i < limit; i++) {
      final normalized = rows[i]
          .map((cell) => _normalizeHeader(_cellText(cell)))
          .toList(growable: false);
      final anchor = _columnFor(normalized, const <String>[
        'date',
        'day date',
        'day',
        'days',
        'weekday',
        'day of week',
      ]);
      if (anchor == null) continue;

      // A lone anchor is not enough: the header must also name either meals
      // or a dish column, otherwise a title row saying "Day" would win.
      final hasMeals = normalized.any(
        (value) =>
            MealType.fromJson(value) != null || _mealFromLabel(value) != null,
      );
      final hasItems =
          _columnFor(normalized, const <String>[
            'item',
            'items',
            'dish',
            'dishes',
            'menu',
          ]) !=
          null;
      if (hasMeals || hasItems) return i;
    }
    return null;
  }

  int? _columnFor(List<String> header, List<String> candidates) {
    for (var i = 0; i < header.length; i++) {
      if (candidates.contains(header[i])) return i;
    }
    return null;
  }

  Data? _at(List<Data?> row, int index) =>
      (index >= 0 && index < row.length) ? row[index] : null;

  /// Extracts a cell's text, whatever its underlying type.
  String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    return switch (value) {
      TextCellValue() => value.value.toString(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => _trimTrailingZero(value.value),
      BoolCellValue() => value.value.toString(),
      DateCellValue() => value.asDateTimeLocal().toIso8601String(),
      DateTimeCellValue() => value.asDateTimeLocal().toIso8601String(),
      TimeCellValue() => value.toString(),
      FormulaCellValue() => '',
    };
  }

  /// Reads a cell as a calendar date, accepting real date cells and the usual
  /// hand-typed spellings.
  DateTime? _cellDate(Data? cell) {
    final value = cell?.value;
    if (value is DateCellValue) return value.asDateTimeLocal();
    if (value is DateTimeCellValue) {
      final dt = value.asDateTimeLocal();
      return DateTime(dt.year, dt.month, dt.day);
    }

    final text = _cellText(cell).trim();
    if (text.isEmpty) return null;

    final iso = DateTime.tryParse(text);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    // dd/MM/yyyy and dd-MM-yyyy, the forms a mess office actually types.
    final match = RegExp(
      r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$',
    ).firstMatch(text);
    if (match == null) return null;

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  String _normalizeHeader(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'[_\s]+'), ' ').trim();

  String _trimTrailingZero(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  String _firstNonEmpty(String a, String b) => a.trim().isEmpty ? b : a;

  /// Splits a cell into dishes and pulls any inline veg/non-veg marker off the
  /// name.
  ///
  /// Slashes are deliberately *not* separators: mess menus write
  /// "Tea/Coffee/Milk" and "Chicken Biryani/Veg Biryani" to mean one serving
  /// choice, and splitting them would invent dishes.
  List<_ParsedItem> _splitItems(String cell) {
    final parts = cell
        .split(RegExp(r'[\n\r;,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    final items = <_ParsedItem>[];
    for (final part in parts) {
      final parsed = _parseItem(part);
      if (parsed != null) items.add(parsed);
    }
    return items;
  }

  _ParsedItem? _parseItem(String raw) {
    var name = raw.trim();
    if (name.isEmpty) return null;

    ItemVariant? variant;
    final marker = RegExp(
      r'[\(\[]\s*(veg|non[\s\-_]?veg|nonveg)\s*[\)\]]\s*$',
      caseSensitive: false,
    ).firstMatch(name);

    if (marker != null) {
      final token = marker.group(1)!.toLowerCase().replaceAll(
        RegExp(r'[\s\-_]'),
        '',
      );
      variant = token == 'veg' ? ItemVariant.veg : ItemVariant.nonVeg;
      name = name.substring(0, marker.start).trim();
    }

    // Trailing punctuation left behind by a stripped marker.
    name = name.replaceAll(RegExp(r'[\s\-–—:]+$'), '').trim();
    if (name.isEmpty) return null;
    return _ParsedItem(name: name, variant: variant);
  }

  /// Recognises meal names that are not exactly the contract literal.
  MealType? _mealFromLabel(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-_]'),
      '',
    );
    if (normalized.isEmpty) return null;
    if (normalized.startsWith('break') || normalized == 'bf') {
      return MealType.breakfast;
    }
    if (normalized.startsWith('lunch') || normalized == 'afternoon') {
      return MealType.lunch;
    }
    if (normalized.startsWith('snack') ||
        normalized.startsWith('evening') ||
        normalized == 'tea' ||
        normalized == 'teatime') {
      return MealType.snacks;
    }
    if (normalized.startsWith('dinner') ||
        normalized.startsWith('supper') ||
        normalized.startsWith('night')) {
      return MealType.dinner;
    }
    return null;
  }

  /// Slugifies a tier label, mapping the two known tiers onto their contract
  /// ids so an imported sheet lines up with a downloaded document.
  String _tierId(String label) {
    final normalized = label.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (normalized.isEmpty) return AppConfig.defaultMessId;
    if (normalized.contains('special') || normalized.contains('premium')) {
      return AppConfig.messIdSpecial;
    }
    if (normalized.contains('nonveg') ||
        normalized.contains('vegandnonveg') ||
        normalized == 'veg' ||
        normalized == 'regular' ||
        normalized == 'standard' ||
        normalized == 'sheet1') {
      return AppConfig.messIdVegNonVeg;
    }
    return label.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  String _tierName(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return 'Veg & Non-Veg';
    final id = _tierId(trimmed);
    if (id == AppConfig.messIdVegNonVeg && _looksGeneric(trimmed)) {
      return 'Veg & Non-Veg';
    }
    if (id == AppConfig.messIdSpecial && _looksGeneric(trimmed)) {
      return 'Special';
    }
    return trimmed;
  }

  bool _looksGeneric(String label) {
    final normalized = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.startsWith('sheet') || normalized.isEmpty;
  }

  String _inferMonth(List<Mess> messes) {
    for (final mess in messes) {
      if (mess.days.isNotEmpty) return Menu.monthKeyOf(mess.days.first.date);
    }
    return '';
  }
}

/// The month a sheet covers.
@immutable
class _Period {
  const _Period(this.year, this.month);

  final int year;
  final int month;

  /// Last day of the month, used to discard out-of-range day numbers.
  int get lastDay => DateTime(year, month + 1, 0).day;
}

/// A weekday and/or the day numbers written in an anchor cell.
@immutable
class _DayMarker {
  const _DayMarker({required this.weekday, required this.days});

  final String? weekday;
  final List<int> days;
}

/// One run of rows that share a day heading.
class _Block {
  _Block({
    required this.tierLabel,
    this.explicitDate,
    this.weekday,
    this.dayNumbers = const <int>[],
  });

  final String tierLabel;
  final DateTime? explicitDate;
  final String? weekday;
  final List<int> dayNumbers;
  final Map<MealType, List<MealItem>> meals = <MealType, List<MealItem>>{};

  void add(MealType meal, MealItem item) =>
      meals.putIfAbsent(meal, () => <MealItem>[]).add(item);

  /// Every calendar date this block applies to.
  ///
  /// A block carrying day numbers repeats on each of them. A block naming only
  /// a weekday falls back to every matching weekday in the month, which is how
  /// a plain seven-row rotation sheet is handled.
  List<DateTime> datesIn(_Period period) {
    final explicit = explicitDate;
    if (explicit != null) return <DateTime>[explicit];

    if (dayNumbers.isNotEmpty) {
      return dayNumbers
          .where((day) => day >= 1 && day <= period.lastDay)
          .map((day) => DateTime(period.year, period.month, day))
          .toList(growable: false);
    }

    final label = weekday;
    if (label == null) return const <DateTime>[];

    final dates = <DateTime>[];
    for (var day = 1; day <= period.lastDay; day++) {
      final date = DateTime(period.year, period.month, day);
      if (ExcelMenuParser._weekdayAbbrev(date) == label) dates.add(date);
    }
    return dates;
  }
}

/// A dish name with any inline variant marker already removed.
@immutable
class _ParsedItem {
  const _ParsedItem({required this.name, this.variant});

  final String name;
  final ItemVariant? variant;
}

/// Accumulates one tier's days while the sheet is walked.
class _TierBuilder {
  _TierBuilder({required this.id, required this.name});

  final String id;
  final String name;

  /// dateKey -> day, insertion ordered.
  final Map<String, _DayBuilder> _days = <String, _DayBuilder>{};

  void add({
    required DateTime date,
    required MealType meal,
    required MealItem item,
    MinuteOfDay? start,
    MinuteOfDay? end,
  }) {
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final day = _days.putIfAbsent(key, () => _DayBuilder(date));
    day.add(meal, item, start: start, end: end);
  }

  Mess? build() {
    if (_days.isEmpty) return null;
    final days = _days.values
        .map((builder) => builder.build())
        .toList(growable: false);
    return Mess(id: id, name: name, days: days);
  }
}

class _DayBuilder {
  _DayBuilder(this.date);

  final DateTime date;
  final Map<MealType, List<MealItem>> _items = <MealType, List<MealItem>>{};
  final Map<MealType, MinuteOfDay> _starts = <MealType, MinuteOfDay>{};
  final Map<MealType, MinuteOfDay> _ends = <MealType, MinuteOfDay>{};

  void add(
    MealType meal,
    MealItem item, {
    MinuteOfDay? start,
    MinuteOfDay? end,
  }) {
    _items.putIfAbsent(meal, () => <MealItem>[]).add(item);
    if (start != null) _starts[meal] = start;
    if (end != null) _ends[meal] = end;
  }

  MenuDay build() {
    final meals = <Meal>[];
    for (final type in MealType.values) {
      final items = _items[type];
      if (items == null || items.isEmpty) continue;

      // The sheet carries no times, so the canonical window for this slot on
      // this date is used — which is how Sunday and Monday pick up the later
      // breakfast.
      final start = _starts[type] ?? type.startOn(date);
      var end = _ends[type] ?? type.endOn(date);
      if (end <= start) end = type.endOn(date);

      meals.add(Meal(type: type, startTime: start, endTime: end, items: items));
    }
    return MenuDay(
      date: date,
      weekday: _weekdayLabels[date.weekday - 1],
      meals: meals,
    );
  }

  static const List<String> _weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
}
