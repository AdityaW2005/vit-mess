import '../core/utils/result.dart';
import '../models/developer.dart';

/// Acts on a [DeveloperLink].
///
/// Keeps `url_launcher` and the clipboard out of the ViewModel layer, and puts
/// the "open it or copy it" decision in one testable place.
abstract class LinkRepository {
  /// Opens [link], or copies it when it is an address.
  ///
  /// Succeeds with `true` when the target was copied rather than opened, which
  /// is what the UI turns into "Email copied".
  Future<Result<bool>> follow(DeveloperLink link);
}
