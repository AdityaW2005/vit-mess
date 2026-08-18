# MessMate

The VIT-AP hostel mess menu, answered in under two seconds.

Open the app and the first thing on screen is what is being served right now
and how long you have — a live countdown, the full item list, no taps. Between
meals it flips to the next one. After dinner it rolls over to tomorrow's
breakfast. Everything else (browsing the month, searching for a dish, settings)
is secondary navigation.

---

## Running it

```bash
flutter pub get
```

```bash
flutter run
```

Requires Flutter **3.41+** on the stable channel (Dart 3.11, sound null safety).
Targets Android and iOS.

Platform minimums, already configured:

| Platform | Minimum | Why |
| --- | --- | --- |
| Android | `flutter.minSdkVersion` with core library desugaring enabled | `flutter_local_notifications` needs `java.time` backported |
| iOS | 14.0 | `file_picker_darwin` requires it |

### Tests

```bash
flutter test
```

128 tests covering the pure time logic, model parsing (including malformed
documents), Excel workbook parsing in all three supported layouts, dish
classification, the repository's cache-fallback policy, and rendering of the
3-item / 13-item extremes and paired veg/non-veg tiles.

Drop a real published menu at `test/fixtures/vitap_august_2026.xlsx` to also
run `real_workbook_test.dart` against the genuine article; without it those
checks skip and the synthetic rotation fixture covers the same format.

```bash
flutter analyze
```

Clean under the default `flutter_lints` set.

---

## Where to set the menu URL

**`lib/core/config/app_config.dart` → `AppConfig.menuUrl`.**

```dart
static const String menuUrl =
    'https://raw.githubusercontent.com/vitap-messmate/menu-data/main/menu.json';
```

That constant is the only place the network source is named. It currently holds
a **placeholder** GitHub raw URL — point it at your own repository before
shipping. Everything else about the fetch (timeout, cache keys, schema version)
lives in the same file.

While `menuUrl` still equals `AppConfig.placeholderMenuUrl`, the app treats
downloading as unavailable: it never fires a request that is guaranteed to
fail, Settings hides **Refresh now** and explains that the spreadsheet is the
only source, and pull-to-refresh is a no-op. Replace the constant and all of
that turns on by itself — `AppConfig.isRemoteConfigured` derives from it, so
there is no second flag to remember.

---

## Getting a menu into the app

There is **no bundled menu**. On a fresh install the app tries the remote
document once, and if that fails every screen shows a centred **"Import your
mess menu"** prompt whose primary action opens the file picker. Once a menu is
imported or downloaded it is cached, and the app works offline from then on.

Two ways a menu arrives:

1. **Import an Excel workbook (primary in practice).** Tap *Choose a
   spreadsheet* on the empty state, or Settings → *Import a menu spreadsheet*.
   Accepts `.xlsx` / `.xlsm`. The workbook is converted to the internal JSON
   contract and cached, so the cache format never depends on where a menu came
   from.
2. **Remote JSON.** Commit `menu.json` to the menu-data repository on `main`
   and every device picks it up on next launch. See
   [Where to set the menu URL](#where-to-set-the-menu-url).

### The spreadsheet format

Each **worksheet is one subscription tier** — the sheet name becomes the tier
name (`Veg & Non-Veg`, `Special`). Three layouts are recognised, chosen per
sheet by inspecting the header row, so a menu can be kept in whichever shape
the mess office already uses.

**Rotation** — what the VIT-AP mess office actually publishes. A `Day` column
carries the weekday plus the dates of the month that repeat it (usually a
merged cell spanning the block), and each meal column lists one dish per row
underneath:

| Day | Breakfast | Lunch | Snacks | Dinner |
|-----|-----------|-------|--------|--------|
| Sat<br>1, 15, 29 | Masala Ghee Roast Dosa | Carrot & Cucumber Salad | Punugulu 10 Pcs | Beetroot & Carrot Salad |
| | Vada Pav | Pulka | Groundnut Chutney | Roti |
| | Groundnut Chutney | White Rice | Ginger Tea/Coffee/Milk | White Rice |
| Sun<br>2, 16, 30 | Shavige Bath | … | … | … |

The block repeats onto every date it names, so one fortnight of rows fills the
whole month.

**Grid** — one row per day, keyed by an explicit date:

| Date | Breakfast | Lunch | Snacks | Dinner |
|------|-----------|-------|--------|--------|
| 2026-08-17 | Carrot Idly, Medhu Vada | Steamed Rice, Chicken Curry (non-veg), Paneer (veg) | Masala Tea | Chapathi |

**Long** — one row per dish:

| Date | Meal | Item | Variant |
|------|------|------|---------|
| 2026-08-17 | Breakfast | Carrot Idly | |
| 2026-08-17 | Lunch | Chicken Curry | nonveg |
| 2026-08-17 | Lunch | Paneer Butter Masala | veg |

### Which month a rotation sheet covers

A rotation sheet names its month in the title above the header
("VEG & NON-VEG MESS MENU FOR THE MONTH OF **AUGUST**") but usually omits the
year. The year is recovered from the sheet's own data: the only candidate year
that makes the weekday labels agree with the day numbers is the right one —
1, 15 and 29 August fall on a Saturday in 2026 and in no other nearby year. If
the title carries a year it is used directly; if it names no month at all, the
current month is assumed.

### What the parser tolerates

So a hand-kept sheet does not need cleaning up first:

- **Merged day cells** spanning a block of rows.
- **Dates** as real Excel date cells, `2026-08-17`, `17/08/2026` or `17-08-26`.
- **Title rows** above the header — the header is searched for, not assumed to
  be row 1.
- **Blank Date / Meal cells**, which carry down from the row above.
- **Loose meal headings**: `BREAKFAST `, `Evening Snacks`, `Supper`, `Tea`, `BF`.
- **Several dishes in one cell**, separated by newlines, commas or semicolons.
- **Slash choices are left alone.** `Tea/Coffee/Milk` and `Chicken Dum
  Biryani/Vegetable Dum Biryani` stay one line, because a slash means "one of
  these" — splitting on it would invent dishes.
- **Veg / non-veg markers** written inline as `Telangana Chicken Curry
  (Non-Veg)` or in a dedicated `Variant` column. On the **Veg & Non-Veg** plan,
  two marked dishes on adjacent rows of the same meal are folded into a single
  "or" tile — the mess serves one or the other. On the **Special** plan both
  are served, so they stay as two separate rows.
- **Trailing prose** — a `MESS SERVICE INSTRUCTIONS` block after the last day
  is detected and excluded, as is anything following it.
- **Optional columns**: `Mess` / `Plan` / `Tier` (overrides the sheet name and
  lets one sheet hold both tiers), and `Start` / `End` to override that meal's
  serving window.
- **Unreadable sheets** are skipped rather than failing the whole import, so a
  "Notes" tab alongside the menu is harmless.

A workbook with no `Day`/`Date` column, or no recognisable meal columns, is
rejected with a plain-language message rather than importing an empty menu.

### Meal timings

Serving windows are **not** read from the spreadsheet. They come from
`MealType`'s canonical windows in `lib/models/meal.dart`, matching the mess
office's published timings board:

| Meal | Window |
| --- | --- |
| Breakfast (Tue–Sat) | 07:00 – 09:00 |
| Breakfast (Sun & Mon) | 07:15 – 09:15 |
| Lunch | 12:30 – 14:15 |
| Snacks | 16:30 – 18:15 |
| Dinner | 19:15 – 21:00 |

Breakfast is the one slot that runs to two clocks, so `MealType.startOn(date)`
/ `endOn(date)` resolve it per weekday and the Excel parser bakes the right
window into each day. Settings notes the Sunday/Monday difference under
Breakfast; a student override replaces both and the note disappears.

Students can override any of them in Settings → *Meal timings* without touching
the data. Overrides live in `MealTimings`
(`lib/core/config/meal_timings.dart`) and are applied on top of whatever the
document says. A `Start` / `End` column in a long-layout sheet overrides the
canonical window for that meal; a student override still wins over both.

### Dish highlighting

A mess menu is mostly staples — rice, dal, chutney, tea. What a student
actually scans for is the one dish that decides the meal, so only that dish is
lifted:

| Dish | Marker |
| --- | --- |
| Non-veg (chicken, mutton, fish, prawn, egg…) | **Red** mark, red name, tinted strip |
| Marquee veg (paneer, mushroom, soya, kofta, chole, rajma, manchurian…) | **Green** mark, green name, tinted strip |
| Everyday staples (rice, sambar, curd, tea…) | Muted neutral mark |

Classification lives in `lib/core/utils/dish_classifier.dart` as a pure,
unit-tested function. An explicit `(Veg)` / `(Non-Veg)` marker in the sheet
always wins; otherwise the dish is judged from its name, so a board that never
tags anything still gets correct marks. Matching is word-boundary aware —
"Eggless Cake" and "Beans Poriyal" are not mistaken for egg and beans.

Both tiers use the same rules, and the highlight stays deliberately faint (a
9% tint and a 3px rule) so the now-serving card remains the only saturated
element on the screen.

### Appearance

Both themes ship complete and are switchable in-app: Settings → **Appearance**
offers *System* / *Light* / *Dark*. The choice is persisted with the rest of the
settings and applies immediately, without a restart.

The palette is defined once as a `MessColors` `ThemeExtension`
(`lib/core/theme/app_theme.dart`) with a light and a dark instance, so every
semantic role — canvas, surface, hairline, accent, the veg/non-veg markers, the
now-serving gradient — has a value in both. Widgets read `context.mess` and
never hardcode a colour, which is what keeps the two themes in step.

The design is dark-first (deep charcoal-brown, saffron accent); the light theme
is a warm off-white with a deeper amber accent so the same saturation hierarchy
survives — the now-serving card stays the only saturated element in both.

### JSON contract (remote + cache)

```jsonc
{
  "schemaVersion": 1,
  "month": "2026-08",          // yyyy-MM, must match the month it covers
  "campus": "VIT-AP",
  "messes": [                  // exactly two: "veg-nonveg" and "special"
    {
      "id": "veg-nonveg",
      "name": "Veg & Non-Veg",
      "days": [                // every day of the month, flat and date-keyed
        {
          "date": "2026-08-17",
          "weekday": "Mon",
          "meals": [           // in order
            {
              "type": "breakfast",   // breakfast | lunch | snacks | dinner
              "startTime": "07:15",  // HH:mm, 24-hour
              "endTime": "09:00",
              "items": [
                { "name": "Carrot Idly", "variant": null },
                { "name": "Telangana Chicken Curry", "variant": "nonveg" },
                { "name": "Achari Paneer", "variant": "veg" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

`days` is a flat date-keyed list — there is no weekday-rotation logic on the
client, a date lookup is direct. Parsing degrades rather than crashing: a
malformed item is dropped, a malformed window falls back to the canonical one,
a malformed day is skipped, and a document that yields no tier at all is
rejected wholesale with the previous cache left intact.

## Architecture

Strict MVVM with `provider` + `ChangeNotifier`, dependencies resolved through
`get_it`. The layering is enforced without exception:

```
View  ──reads──>  ViewModel  ──depends on──>  Repository (interface)
                                                    │
                                                    ▼
                                              Service (HTTP / disk / platform)
```

### Layer responsibilities

| Layer | Owns | Never does |
| --- | --- | --- |
| **Views** (`lib/views`) | Layout, animation, local widget state (expansion, text controllers) | Business logic; calling a service or repository; `setState` for anything a ViewModel owns |
| **ViewModels** (`lib/viewmodels`) | Derived state, the one-second ticker, loading/error lifecycle | Importing Flutter widget libraries; touching concrete implementations or services |
| **Repositories** (`lib/repositories`) | Caching policy, scheduling policy, returning `Result<T>` | Throwing to the ViewModel layer |
| **Services** (`lib/services`) | HTTP, `SharedPreferences`, file picking, Excel decoding, notifications | Anything above them |
| **Models** (`lib/models`) | Immutable value types, `fromJson`/`toJson`, `copyWith`, equality | Crashing on a missing or null field |

A few consequences worth calling out:

- **ViewModels import only `package:flutter/foundation.dart`.** `ChangeNotifier`
  lives there; widgets do not. This is what keeps them unit-testable.
- **Repositories return `Result<T>`** — a sealed `Success | Failure` with a
  `FailureKind` the UI maps to a designed error screen. No exception ever
  reaches a ViewModel.
- **Views never see a `Result`.** ViewModels expose `state`, `errorKind` and
  `errorMessage`; `ErrorState.forFailure` turns those into a screen.
- **Settings changes broadcast.** `SettingsRepository` exposes a stream, so
  switching tier on the Settings screen updates Home, Week and Search without
  any of them knowing the others exist.

### Caching and offline behaviour

`MenuRepositoryImpl.getMenu()` resolves in this order, and **never blocks on the
network**:

1. the cached document, returned immediately;
2. a live fetch, only if nothing is cached;
3. otherwise a `FailureKind.empty` failure, which every screen renders as the
   centred import prompt.

`refreshMenu()` then runs in the background. If it fails:

- **with a menu already on screen** → the cache is kept and the failure shows as
  a quiet "last updated" line, never an error banner;
- **with nothing on screen** → a full error state with *Try again* and *Import a
  file instead*.

If the cached month no longer matches the current month, the snapshot reports
itself stale, a refresh is attempted, and a failure surfaces the
"menu for this month isn't up yet" state.

The repository also exposes `Stream<MenuSnapshot> changes`, emitted whenever a
menu is adopted. Home, Week, Search and Settings all subscribe, so importing a
spreadsheet on any screen updates the others without them knowing each other
exists.

The app is fully usable offline after the first successful load.

### Time logic

`MealStatus resolveStatus(Meal meal, DateTime now)` in
`lib/core/utils/date_utils.dart` is a pure function, and every screen derives
its appearance from it:

- `servingNow` when `startTime <= now <= endTime`
- `upcoming` when `now < startTime`
- `closed` when `now > endTime`

Times are parsed into `MinuteOfDay` (minutes since midnight) and compared
numerically, never as strings. Exactly one meal can be `servingNow`; if user
overrides make two windows overlap, the earliest-starting one wins.
`resolveFocus` handles the day rollover — after dinner it looks up the next day
the document covers, and returns `null` on the last day of the month, which the
UI renders as the "not up yet" state. All comparisons use device-local time; no
timezone is assumed.

### Project layout

```
lib/
├── main.dart                      # wires DI, then runApp
├── app.dart                       # MaterialApp, themes, routes, onboarding gate
├── core/
│   ├── config/                    # app_config.dart (menuUrl!), meal_timings.dart
│   ├── constants/strings.dart     # every user-facing string
│   ├── theme/                     # colours, typography, ThemeExtension
│   ├── utils/                     # date_utils.dart (resolveStatus), result.dart
│   └── service_locator.dart       # get_it registrations
├── models/                        # immutable, self-parsing value types
├── services/                      # HTTP, storage, file picking, Excel parsing,
│                                  #   notifications
├── repositories/                  # interfaces + impls, caching & reminder policy
├── viewmodels/                    # BaseViewModel + one per screen
├── views/                         # home, week, search, settings, onboarding, shell
└── widgets/                       # hero card, countdown, meal card, day strip, …
```

---

## Notifications

A local notification fires 15 minutes before each enabled meal opens, carrying
the meal name and its first three dishes. The schedule is rebuilt from scratch
on every tier change, timing change and menu refresh, so it can never drift or
duplicate. Permission is requested at the moment the student turns reminders on
— not as a cold-start surprise — and a decline is handled gracefully: the switch
stays off and Settings explains why.

Reminders are scheduled **inexactly** (`inexactAllowWhileIdle`), which means the
app does not need Android's `SCHEDULE_EXACT_ALARM` permission. A reminder does
not need second-level precision.
