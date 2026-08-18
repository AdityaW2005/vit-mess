import '../core/utils/result.dart';
import '../models/menu.dart';

/// Supplies the monthly menu document to the ViewModel layer.
///
/// Every method returns a [Result]; nothing here ever throws. The caching
/// policy — what is cached, when it is written, and what the fallback order is
/// — belongs to the implementation, not to callers.
abstract class MenuRepository {
  /// Emits whenever a new menu is adopted, from a refresh or an import.
  ///
  /// Broadcast, so Home, Week and Search all see an import performed on any
  /// screen without knowing about each other.
  Stream<MenuSnapshot> get changes;

  /// Returns a menu without waiting on the network.
  ///
  /// Resolution order: the cached document, then a live fetch if nothing is
  /// cached. After the first successful load the UI can render immediately on
  /// every launch.
  ///
  /// Fails with [FailureKind.empty] when there is no cache and the network
  /// cannot supply one — the state where the UI asks the student to import a
  /// spreadsheet.
  Future<Result<MenuSnapshot>> getMenu();

  /// Fetches the JSON document from `AppConfig.menuUrl` and caches it.
  ///
  /// Returns a failure when the network is unavailable; callers that already
  /// hold a snapshot should keep showing it rather than surfacing an error.
  Future<Result<MenuSnapshot>> refreshMenu();

  /// Lets the student pick an Excel workbook, converts it, and caches it.
  ///
  /// Returns a [FailureKind.cancelled] failure when the picker is dismissed.
  Future<Result<MenuSnapshot>> importMenu();

  /// When the cached document was last fetched or imported.
  Future<DateTime?> lastUpdated();

  /// Discards the cached document, returning the app to the import prompt.
  Future<Result<void>> clearCache();

  /// Releases the change stream.
  Future<void> dispose();
}
