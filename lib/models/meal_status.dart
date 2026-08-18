/// Where a meal sits relative to "now".
///
/// Derived exclusively from `resolveStatus` in `core/utils/date_utils.dart` so
/// that every screen agrees about what is being served.
enum MealStatus {
  /// The meal has not opened yet today.
  upcoming,

  /// `startTime <= now <= endTime`.
  servingNow,

  /// The serving window has passed.
  closed;

  /// True for the single saturated, highlighted state.
  bool get isServing => this == MealStatus.servingNow;

  /// True when the meal is still ahead.
  bool get isUpcoming => this == MealStatus.upcoming;

  /// True when the meal is done for the day.
  bool get isClosed => this == MealStatus.closed;
}
