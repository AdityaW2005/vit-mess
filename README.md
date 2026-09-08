# MessUp

**The VIT-AP hostel mess menu, answered in under two seconds.**

Open the app and the first thing on screen is what is being served right now
and how long you have — a live countdown, the full dish list, no taps. Between
meals it flips to the next one. After dinner it rolls over to tomorrow's
breakfast. Browsing the month, searching for a dish and settings are all
secondary; the hero answer is the product.

There is no server. The mess committee publishes a spreadsheet each month, a
student imports it once, and everything after that works offline.

---

## Contents

- [What it does](#what-it-does)
- [How a menu gets in](#how-a-menu-gets-in)
- [Meal timings](#meal-timings)
- [Dish highlighting](#dish-highlighting)
- [Reminders](#reminders)
- [Architecture](#architecture)
- [Data flow](#data-flow)
- [Time logic](#time-logic)
- [Storage and offline behaviour](#storage-and-offline-behaviour)
- [Analytics](#analytics)
- [Project layout](#project-layout)
- [Running it](#running-it)

---

## What it does

Four tabs, in the order a hungry student needs them.

| Tab | Answers |
| --- | --- |
| **Today** | What is being served *now*, how long is left, and what is still to come today. A saffron hero card counts down to closing time while a counter is open, and to opening time when it is not. |
| **Week** | The whole month, one day at a time. A horizontal day strip scrolls to today; each meal is a collapsible card. |
| **Search** | Every dish in the month, grouped by date with a "TODAY / IN 2 DAYS / IN 5 DAYS" heading, so "when is paneer next?" takes one query. |
| **Settings** | Mess plan, serving-window overrides, per-meal reminders, menu import, light/dark, about. |

First launch shows a one-screen onboarding that picks the subscription tier
(**Veg & Non-Veg** or **Special**) and offers reminders. With no menu loaded,
every screen shows a centred import prompt rather than an empty shell.

## How a menu gets in

Importing a spreadsheet is the primary path — the one students actually use.
Settings → **Menu data** → *Import a menu spreadsheet* opens the system file
picker for an `.xlsx` or `.xlsm` workbook.

The parser recognises **three layouts**, chosen per worksheet by inspecting the
header row, because real mess menus arrive in all of them.

**Rotation** — the shape the VIT-AP mess office publishes. A `Day` column holds
a weekday and the dates of the month that repeat it; each meal column lists one
dish per row underneath:

| Day | Breakfast | Lunch | Snacks | Dinner |
| --- | --- | --- | --- | --- |
| Sat<br>1, 15, 29 | Masala Dosa | Carrot Salad | Punugulu | Roti |
| | Vada Pav | Pulka | Chutney | White Rice |

**Grid** — one row per day, keyed by an explicit date:

| Date | Breakfast | Lunch |
| --- | --- | --- |
| 2026-08-17 | Carrot Idly, Vada | Rice, Chicken Curry (non-veg) |

**Long** — one row per dish:

| Date | Meal | Item | Variant |
| --- | --- | --- | --- |
| 2026-08-17 | Lunch | Chicken Curry | nonveg |

Each **worksheet is one subscription tier** and the sheet name becomes the tier
name; a `Mess` / `Plan` / `Tier` column overrides that when present.

### Recovering the year

A rotation sheet titles itself `AUGUST` with no year. The parser recovers it by
**weekday alignment**: only one nearby year puts the 1st, 15th and 29th on a
Saturday. Candidate years around today are tested and the one that fits wins.

### What the parser tolerates

Real spreadsheets are messy, so the parser absorbs rather than rejects:

- merged day cells, blank spacer rows, and title rows above the header
- loose headings — `BREAKFAST `, `Evening Snacks`, `Supper`
- dates as `2026-08-17`, `17/08/2026`, or a native Excel date cell
- several dishes in one cell, split on newlines, semicolons or commas —
  deliberately **not** on `/`, so `Tea/Coffee/Milk` stays one item
- a blank date carried down from the row above
- service instructions and footer notes, which are dropped

A workbook that yields no menu rows at all is rejected wholesale with a plain
explanation, and the existing menu is left untouched.

### Importing an out-of-date month

A spreadsheet for a month that has already passed is almost always the wrong
file — adopting it would overwrite a menu still in use and silently clear every
reminder. So the parse happens first, and then the app asks:

> **This menu has expired**
> This spreadsheet is for August 2026, which has already passed. Importing it
> replaces your September 2026 menu and clears any meal reminders.
> **Keep current menu** · Import anyway

Nothing is written until the answer is yes; dismissing the dialog counts as no.
Only *past* months prompt — next month's file, which arrives before the month
starts, imports silently. If it is imported anyway, the Settings status card
turns amber (*Menu has expired*) instead of showing a green tick.

## Meal timings

Serving windows are **not** read from the spreadsheet. They come from
`MealType`'s canonical windows in `lib/models/meal.dart`, matching the mess
notice board:

| Meal | Window |
| --- | --- |
| Breakfast (Tue–Sat) | 07:00 – 09:00 |
| Breakfast (Sun & Mon) | 07:15 – 09:15 |
| Lunch | 12:30 – 14:15 |
| Snacks | 16:30 – 18:15 |
| Dinner | 19:15 – 21:00 |

Breakfast is the one slot that runs two clocks, so `MealType.startOn(date)` and
`endOn(date)` are date-aware. Any window can be overridden per meal in Settings;
an override replaces both weekday variants and is marked **Custom** with a
one-tap reset.

## Dish highlighting

A mess menu is mostly staples — rice, dal, chutney, tea. What a student scans
for is the dish that decides the meal. `classifyDishName` marks those and
leaves everything else quiet, so a highlight actually means something:

- **green** — marquee vegetarian: paneer, mushroom, soya and friends
- **red** — non-vegetarian
- **neutral** — everything else

Matching is word-boundary aware, so `Eggless Cake` is not caught by `egg` and
`Beans Poriyal` is not caught by `bean`. A dish naming both — `Chicken Dum
Biryani/Paneer Dum Biryani` — reads as non-veg, because that is what is served
to whoever takes it. An explicit veg/non-veg marker in the sheet always wins
over the guess.

On the **Veg & Non-Veg** plan an adjacent veg/non-veg pair is one either/or
choice and renders as a single tile. On **Special**, where both are served, they
stay separate rows.

## Reminders

A local notification fires 15 minutes before each enabled meal opens, carrying
the meal name and its first three dishes. Seven days are scheduled ahead —
28 alarms at four meals a day — and the whole schedule is **rebuilt from
scratch** on every tier change, timing change, menu change and app resume, so it
can never drift or duplicate.

Reminders use `exactAllowWhileIdle`: a nudge the system batches half an hour
late is worse than no nudge. When Android withholds that permission the app
falls back to inexact scheduling rather than failing, and Settings says so —
separately for "notifications are switched off entirely" and "these may arrive
late".

Permission is requested at the moment reminders are switched on, never as a
cold-start surprise, and a decline leaves the switch off with an explanation.

## Architecture

Strict **MVVM**, one direction only:

```
View  ──watches──▶  ViewModel  ──calls──▶  Repository (interface)
                                                 │
                                                 ▼
                                            Service (platform)
```

- **Views** are `StatelessWidget`/`StatefulWidget` and hold no logic beyond
  layout and gesture wiring. They read state through `Consumer`/`context.read`.
- **ViewModels** extend `BaseViewModel` (a `ChangeNotifier`) and import only
  `package:flutter/foundation.dart` — never a widget, a `BuildContext`, or a
  service. They depend on repository *interfaces*, which is what makes them
  testable with fakes.
- **Repositories** are interfaces with one implementation each. They own
  policy: caching order, reminder scheduling rules, analytics consent.
- **Services** are the only files that touch a plugin or the platform — HTTP,
  shared preferences, the file picker, the Excel decoder, notifications,
  `url_launcher`, package info.
- **Models** are immutable, self-parsing value types with `==`/`hashCode`.

`provider` supplies ViewModels to the tree; `get_it` owns construction in a
single `lib/core/service_locator.dart`. Nothing else registers dependencies.

Every failure crosses a layer boundary as a sealed `Result<T>` — `Success` or
`Failure` carrying a `FailureKind` (`network`, `parse`, `storage`, `cancelled`,
`permission`, `empty`, `unsupported`, `unknown`). The UI picks its illustration
and its action from the kind; no exception escapes a repository.

### Layer responsibilities

| Layer | Knows about | Never knows about |
| --- | --- | --- |
| View | its ViewModel, theme, strings | repositories, services, plugins |
| ViewModel | repository interfaces | widgets, `BuildContext`, plugins |
| Repository | services, models, policy | Flutter widgets |
| Service | one plugin or platform API | the rest of the app |

## Data flow

An import, end to end:

1. **View** — Settings calls `viewModel.importMenu(confirmStaleMonth: …)`,
   passing a callback that can show a dialog.
2. **ViewModel** — flips `isImporting`, notifies, delegates to the repository.
3. **Repository** — asks `FileImportService` for a workbook, hands the bytes to
   `ExcelMenuParser`, checks the month, invokes the confirmation callback if it
   has passed, then normalises the result to the JSON contract and writes it
   through `LocalStorageService`.
4. **Broadcast** — the repository emits the new `MenuSnapshot` on a broadcast
   stream. Home, Week and Search are subscribed, so all four tabs update without
   any of them knowing the others exist.
5. **Side effects** — the settings ViewModel reschedules reminders; the
   analytics repository records the import's shape.

Settings changes follow the same shape through `SettingsRepository.changes`, so
switching tier on the Settings tab updates Today before the animation finishes.

## Time logic

All of it is pure and unit tested; no widget recomputes state during a build.

`resolveStatus(meal, now)` in `lib/core/utils/date_utils.dart` is the single
source of truth:

- `servingNow` when `startTime <= now <= endTime`
- `upcoming` when `now < startTime`
- `closed` when `now > endTime`

`resolveFocus(mess, now, timings)` picks what the hero card leads with:

1. a meal being served right now, else
2. the next meal still to open today, else
3. the first meal of the next day the document covers — the after-dinner
   rollover.

It returns `null` when the month runs out, which is what renders the
"next month isn't up yet" state.

Times are compared as `MinuteOfDay` — minutes since midnight — never as
strings. `HomeViewModel` owns a single one-second `Timer.periodic` that drives
the countdown and is cancelled in `dispose`; no other screen runs a ticker.

## Storage and offline behaviour

The rule the whole app depends on: **never block the first frame on the
network.**

- `getMenu()` answers from disk. If the cache is empty it tries the network, and
  only then reports `FailureKind.empty`, which the UI renders as the import
  prompt.
- `refreshMenu()` runs afterwards, in the background. A failed refresh never
  clears what is already on screen.
- A cache that no longer parses is treated as *absent*, not as an error, so a
  bad write can never brick the app.
- Imported and downloaded menus are both stored as the same JSON, so the cache
  format never depends on where a menu came from.

Everything lives in `SharedPreferences`: the menu document, its source and
timestamp, and the settings blob. No database, no files on disk.

### JSON contract

```jsonc
{
  "schemaVersion": 1,
  "month": "2026-08",          // yyyy-MM, must match the month it covers
  "campus": "VIT-AP",
  "messes": [                  // one per subscription tier
    {
      "id": "veg-nonveg",
      "name": "Veg & Non-Veg",
      "days": [                // flat and date-keyed, not a weekday rotation
        {
          "date": "2026-08-17",
          "weekday": "Mon",
          "meals": [
            {
              "type": "breakfast",   // breakfast | lunch | snacks | dinner
              "startTime": "07:15",  // HH:mm, 24-hour
              "endTime": "09:00",
              "items": [
                { "name": "Carrot Idly", "variant": null },
                { "name": "Chicken Curry", "variant": "nonveg" },
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

`days` is flat and date-keyed, so a date lookup is direct — the rotation is
expanded at import time, not re-derived on every read. Parsing degrades rather
than crashing: a malformed item is dropped, a malformed window falls back to the
canonical one, a malformed day is skipped, and a document that yields no tier at
all is rejected with the previous cache left intact.

## Analytics

Usage is measured with **Google Analytics for Firebase**, behind
`AnalyticsRepository` like every other dependency. ViewModels report; views
never touch analytics. Tab changes are reported by each tab's own `onShown()`,
because an `IndexedStack` never pushes a route for a navigator observer to see.

What is recorded is *shape*, not content: which screens are opened, whether
imports succeed, how many days and tiers a document carried, which meals have
reminders on. The one exception is search, which sends the typed term
(lower-cased and capped at 100 characters) alongside its result count, because
"what do students look for and not find" is the point of measuring it. **The
menu itself never leaves the device** — no dish names, no imported file, and no
personal data are ever uploaded.

Consent lives in the repository and is applied at the SDK level, so opting out
stops collection rather than merely dropping events. Analytics can never break
the app: no method returns a failure, every SDK call is wrapped, and an
unconfigured build degrades to console echoes.

## Project layout

```
lib/
├── main.dart                     # wires DI, then runApp
├── app.dart                      # MaterialApp, themes, onboarding gate
├── core/
│   ├── config/                   # app_config.dart, meal_timings.dart
│   ├── constants/                # strings.dart, analytics_events.dart
│   ├── theme/                    # palette, typography, ThemeExtension
│   ├── utils/                    # date_utils, dish_classifier, result
│   └── service_locator.dart      # the only get_it registrations
├── models/                       # immutable, self-parsing value types
├── services/                     # HTTP, storage, file picking, Excel parsing,
│                                 #   notifications, links, build info
├── repositories/                 # interfaces + impls: caching, reminders,
│                                 #   analytics consent, links
├── viewmodels/                   # BaseViewModel + one per screen
├── views/                        # home, week, search, settings, onboarding,
│                                 #   shell
└── widgets/                      # hero card, countdown, meal card, day strip,
                                  #   developer sheet, stale-import dialog
```

Android and iOS only. Every user-facing string lives in
`core/constants/strings.dart`; widgets never hold literal copy.

### Design

Dark-first, warm: a deep charcoal-brown canvas rather than neutral grey, with
**saffron reserved exclusively for the meal being served right now** — the only
saturated colour in the app, so it always means one thing. Semantic roles live
in a `ThemeExtension<MessColors>`, and both light and dark themes are complete;
the choice is persisted (system / light / dark).

## Running it

```bash
flutter pub get
```

```bash
flutter run
```

Requires Flutter **3.41+** on stable (Dart 3.11, sound null safety). Android
needs core library desugaring, already configured, because
`flutter_local_notifications` uses `java.time`.

### Tests

```bash
flutter test
```

205 tests, no widget golden files and no mocking framework — fakes are written
by hand against the interfaces. Coverage concentrates on the parts that are
easy to get quietly wrong: the Excel parser's three layouts and year inference,
meal-status and focus resolution, cache ordering, reminder scheduling, dish
classification, and the analytics parameter contract.

```bash
flutter analyze
```

Zero warnings is the standing bar.
