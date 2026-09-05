import '../core/constants/strings.dart';
import '../core/utils/result.dart';
import '../models/developer.dart';
import '../services/link_service.dart';
import 'link_repository.dart';

/// Follows developer links through the platform.
class LinkRepositoryImpl implements LinkRepository {
  /// Creates the repository over the link service.
  LinkRepositoryImpl({required LinkService links}) : _links = links;

  final LinkService _links;

  @override
  Future<Result<bool>> follow(DeveloperLink link) async {
    // An address is copied, not launched: a phone with no mail client
    // configured would otherwise show nothing at all when tapped.
    if (link.isEmail) {
      final copied = await _links.copy(link.target);
      return copied
          ? const Result<bool>.success(true)
          : const Result<bool>.failure(
              Strings.developerLinkFailed,
              kind: FailureKind.unsupported,
            );
    }

    final opened = await _links.open(link.uri);
    return opened
        ? const Result<bool>.success(false)
        : const Result<bool>.failure(
            Strings.developerLinkFailed,
            kind: FailureKind.unsupported,
          );
  }
}
