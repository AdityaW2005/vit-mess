import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../models/developer.dart';
import '../viewmodels/settings_view_model.dart';

/// Opens the about-the-developer sheet.
///
/// The ViewModel is read here, in the caller's context, and handed down: the
/// sheet is built by the navigator's overlay and cannot reach a provider that
/// sits below it.
Future<void> showDeveloperSheet(BuildContext context) {
  final viewModel = context.read<SettingsViewModel>();
  viewModel.onDeveloperSheetShown();

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isScrollControlled: true,
    builder: (_) => DeveloperSheet(viewModel: viewModel),
  );
}

/// Who built the app, and how to reach them.
///
/// Deliberately a sheet rather than a route: it is an aside from Settings, and
/// a swipe down gets a student back to what they were doing.
class DeveloperSheet extends StatefulWidget {
  /// Creates the sheet.
  const DeveloperSheet({required this.viewModel, this.links, super.key});

  /// Follows the links and records the taps.
  final SettingsViewModel viewModel;

  /// The contacts to offer. Defaults to whatever [DeveloperProfile] carries;
  /// tests pass their own so they do not depend on build configuration.
  final List<DeveloperLink>? links;

  @override
  State<DeveloperSheet> createState() => _DeveloperSheetState();
}

class _DeveloperSheetState extends State<DeveloperSheet> {
  /// How long a tapped button holds its confirmation before reverting.
  static const Duration _confirmationDuration = Duration(seconds: 2);

  /// The link currently showing a confirmation, if any.
  DeveloperLinkKind? _copied;

  /// The link currently being followed, if any.
  DeveloperLinkKind? _busy;

  String? _error;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _resetTimer = null;
    super.dispose();
  }

  Future<void> _follow(DeveloperLink link) async {
    if (_busy != null) return;
    setState(() {
      _busy = link.kind;
      _error = null;
    });

    final result = await widget.viewModel.followDeveloperLink(link);
    if (!mounted) return;

    // The confirmation is shown inside the sheet rather than as a snack bar,
    // which would be hidden behind it.
    result.fold(
      onSuccess: (copied) {
        setState(() {
          _busy = null;
          _copied = copied ? link.kind : null;
        });
        if (!copied) return;
        _resetTimer?.cancel();
        _resetTimer = Timer(_confirmationDuration, () {
          if (mounted) setState(() => _copied = null);
        });
      },
      onFailure: (failure) => setState(() {
        _busy = null;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;
    final links = widget.links ?? DeveloperProfile.links;

    return Container(
      // Without this the sheet shrink-wraps its widest child, which leaves it
      // narrower than the screen whenever no link button is there to stretch
      // it.
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.cardRadius + 6),
        ),
        border: Border.all(color: colors.hairline),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              const _DeveloperAvatar(),
              const SizedBox(height: 18),

              Text(
                DeveloperProfile.name,
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DeveloperProfile.role,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),

              const SizedBox(height: 18),
              // A short accent rule instead of a full-width divider: it closes
              // the introduction without cutting the sheet in half.
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 22),

              for (var index = 0; index < links.length; index++)
                  Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                    child: _LinkButton(
                      link: links[index],
                      // The first link is the one worth leading with, so it
                      // carries the accent and the rest stay quiet.
                      prominent: index == 0,
                      busy: _busy == links[index].kind,
                      confirmed: _copied == links[index].kind,
                      onTap: () => _follow(links[index]),
                    ),
                  ),

              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: colors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The initials disc, with a waving badge.
///
/// A monogram rather than a photograph: it needs no asset, and it picks up the
/// saffron gradient the rest of the app already uses.
class _DeveloperAvatar extends StatelessWidget {
  const _DeveloperAvatar();

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;

    return SizedBox(
      width: 116,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colors.heroGradientStart,
                  colors.heroGradientEnd,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              DeveloperProfile.initials,
              style: AppTypography.countdownCompact(
                colors.onAccent,
              ).copyWith(fontSize: 34, letterSpacing: 1),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: colors.hairline),
              ),
              alignment: Alignment.center,
              child: const Text('👋', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One full-width contact button.
class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.link,
    required this.prominent,
    required this.busy,
    required this.confirmed,
    required this.onTap,
  });

  final DeveloperLink link;
  final bool prominent;
  final bool busy;
  final bool confirmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;

    final foreground = prominent ? colors.onAccent : colors.accent;
    final background = prominent ? colors.accent : colors.accentTint;
    final label = confirmed
        ? Strings.developerEmailCopied
        : Strings.developerLinkLabel(link.kind);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (busy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else if (confirmed)
                  Icon(Icons.check_rounded, size: 20, color: foreground)
                else
                  _LinkIcon(kind: link.kind, color: foreground),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark for one contact kind.
///
/// GitHub and LinkedIn are brands and Material ships no glyph for either, so
/// those come from Font Awesome. They are drawn with [FaIcon] rather than
/// [Icon]: the brand glyphs are not square, and [Icon]'s square box clips them.
class _LinkIcon extends StatelessWidget {
  const _LinkIcon({required this.kind, required this.color});

  final DeveloperLinkKind kind;
  final Color color;

  /// Brand glyphs read optically smaller than Material's, so they are drawn a
  /// touch larger to sit level with the label.
  static const double _brandSize = 21;

  @override
  Widget build(BuildContext context) => switch (kind) {
    DeveloperLinkKind.github => FaIcon(
      FontAwesomeIcons.github,
      size: _brandSize,
      color: color,
    ),
    DeveloperLinkKind.linkedin => FaIcon(
      FontAwesomeIcons.linkedinIn,
      size: _brandSize,
      color: color,
    ),
    DeveloperLinkKind.email => Icon(
      Icons.alternate_email_rounded,
      size: 20,
      color: color,
    ),
  };
}
