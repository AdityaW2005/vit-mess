import '../services/app_info_service.dart';
import 'app_info_repository.dart';

/// Reads build metadata from the platform.
class AppInfoRepositoryImpl implements AppInfoRepository {
  /// Creates the repository over the app info service.
  AppInfoRepositoryImpl({required AppInfoService info}) : _info = info;

  final AppInfoService _info;

  String? _cached;

  @override
  Future<String?> version() async {
    // The version cannot change while the app is running, so it is read once.
    return _cached ??= await _info.version();
  }
}
