/// Tells the UI which build it is running in.
abstract class AppInfoRepository {
  /// The marketing version, e.g. `1.0.0`.
  ///
  /// `null` when the platform cannot say, in which case the footer simply
  /// omits the line rather than showing a guess.
  Future<String?> version();
}
