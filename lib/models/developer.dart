import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';

/// The kinds of contact the about sheet can offer.
///
/// The kind — not the URL — is what the UI and analytics key off, so a change
/// of hosting never changes an icon or an event name.
enum DeveloperLinkKind {
  /// Source repositories.
  github('github'),

  /// Professional profile.
  linkedin('linkedin'),

  /// An address, copied rather than opened.
  email('email');

  const DeveloperLinkKind(this.id);

  /// Stable identifier, used as an analytics parameter.
  final String id;
}

/// One way to reach the developer.
@immutable
class DeveloperLink {
  /// Creates a link.
  const DeveloperLink({required this.kind, required this.target});

  /// What this link is.
  final DeveloperLinkKind kind;

  /// A URL, or a bare address for [DeveloperLinkKind.email].
  final String target;

  /// True when the target is an address to copy rather than a page to open.
  bool get isEmail => kind == DeveloperLinkKind.email;

  /// The target as a launchable URI.
  ///
  /// A bare `example.com` is assumed to be `https`, so a maintainer pasting a
  /// URL without its scheme still gets a working button.
  Uri get uri {
    if (isEmail) return Uri(scheme: 'mailto', path: target);
    final parsed = Uri.parse(target);
    return parsed.hasScheme ? parsed : Uri.parse('https://$target');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeveloperLink && kind == other.kind && target == other.target);

  @override
  int get hashCode => Object.hash(kind, target);

  @override
  String toString() => 'DeveloperLink(${kind.id})';
}

/// Who built the app, and how to reach them.
///
/// Reads [AppConfig] once and drops anything left blank, which is what lets
/// the about sheet ship before every link exists: an unconfigured entry is
/// absent rather than broken.
class DeveloperProfile {
  const DeveloperProfile._();

  /// Display name.
  static const String name = AppConfig.developerName;

  /// One-line description under the name.
  static const String role = AppConfig.developerRole;

  /// Initials for the avatar.
  static const String initials = AppConfig.developerInitials;

  /// The configured links, in the order the sheet shows them.
  static List<DeveloperLink> get links =>
      List<DeveloperLink>.unmodifiable(<DeveloperLink>[
        for (final entry in const <DeveloperLinkKind, String>{
          DeveloperLinkKind.github: AppConfig.developerGithubUrl,
          DeveloperLinkKind.linkedin: AppConfig.developerLinkedInUrl,
          DeveloperLinkKind.email: AppConfig.developerEmail,
        }.entries)
          if (entry.value.trim().isNotEmpty)
            DeveloperLink(kind: entry.key, target: entry.value.trim()),
      ]);
}
