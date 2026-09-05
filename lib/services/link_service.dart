import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens external destinations and writes to the clipboard.
///
/// The only file that touches `url_launcher`, so a device with no browser or
/// no mail client fails here as `false` rather than throwing into the UI.
class LinkService {
  /// Creates the service.
  LinkService();

  /// Hands [uri] to the platform.
  ///
  /// External destinations open in the system browser rather than a web view,
  /// so an existing login is carried over and the student can share the page.
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      debugPrint('LinkService.open failed for $uri: $error');
      return false;
    }
  }

  /// Puts [text] on the system clipboard.
  Future<bool> copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } on Object catch (error) {
      debugPrint('LinkService.copy failed: $error');
      return false;
    }
  }
}
