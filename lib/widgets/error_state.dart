import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/result.dart';

/// A designed empty / error screen: an icon, plain language, and one clear
/// action.
///
/// Never renders an exception string — [FailureKind] picks the illustration
/// and the copy, so whatever went wrong is explained in words a student can
/// act on.
class ErrorState extends StatelessWidget {
  /// Creates a state screen.
  const ErrorState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.hint,
    this.primaryIcon,
    this.busy = false,
    this.tone = ErrorTone.neutral,
  });

  /// The centred "import your menu" prompt.
  ///
  /// This is what the app shows before any menu exists — the primary action is
  /// picking a spreadsheet, with downloading offered as the quieter fallback.
  factory ErrorState.importPrompt({
    VoidCallback? onImport,
    VoidCallback? onRetry,
    bool busy = false,
  }) => ErrorState(
    icon: Icons.table_chart_outlined,
    title: Strings.importPromptTitle,
    message: Strings.importPromptBody,
    hint: Strings.importPromptFormatHint,
    primaryLabel: Strings.importPromptAction,
    primaryIcon: Icons.upload_file_rounded,
    onPrimary: busy ? null : onImport,
    secondaryLabel: onRetry == null ? null : Strings.importPromptRetry,
    onSecondary: busy ? null : onRetry,
    busy: busy,
  );

  /// Builds the right screen for a failure category.
  ///
  /// Takes the kind and message rather than a `Result`, because that is what a
  /// ViewModel exposes — views never handle `Result` objects themselves.
  factory ErrorState.forFailure({
    required FailureKind kind,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onImport,
    bool busy = false,
  }) {
    // With no bundled menu, "nothing yet" is not an error — it is the import
    // prompt, and importing is the primary action.
    if (kind == FailureKind.empty) {
      return ErrorState.importPrompt(
        onImport: onImport,
        onRetry: onRetry,
        busy: busy,
      );
    }

    // A workbook that could not be read should send the student back to the
    // picker, not to the network.
    if (kind == FailureKind.parse) {
      return ErrorState(
        icon: Icons.grid_off_rounded,
        title: Strings.errorParseTitleSheet,
        message: message,
        tone: ErrorTone.problem,
        primaryLabel: onImport == null ? null : Strings.importPromptAction,
        primaryIcon: Icons.upload_file_rounded,
        onPrimary: busy ? null : onImport,
        secondaryLabel: onRetry == null ? null : Strings.errorRetry,
        onSecondary: busy ? null : onRetry,
        busy: busy,
      );
    }

    final (icon, title, body) = switch (kind) {
      FailureKind.network => (
        Icons.wifi_off_rounded,
        Strings.errorOfflineTitle,
        Strings.errorOfflineBody,
      ),
      _ => (Icons.error_outline_rounded, Strings.errorGenericTitle, message),
    };

    return ErrorState(
      icon: icon,
      title: title,
      message: body,
      tone: ErrorTone.problem,
      primaryLabel: onImport == null ? null : Strings.importPromptAction,
      primaryIcon: Icons.upload_file_rounded,
      onPrimary: busy ? null : onImport,
      secondaryLabel: onRetry == null ? null : Strings.errorRetry,
      onSecondary: busy ? null : onRetry,
      busy: busy,
    );
  }

  /// The illustration glyph.
  final IconData icon;

  /// Short headline.
  final String title;

  /// Plain-language explanation.
  final String message;

  /// Label for the primary action, if there is one.
  final String? primaryLabel;

  /// Primary action.
  final VoidCallback? onPrimary;

  /// Label for the secondary action, if there is one.
  final String? secondaryLabel;

  /// Secondary action.
  final VoidCallback? onSecondary;

  /// Optional smaller line under the message, e.g. the accepted file shape.
  final String? hint;

  /// Optional glyph on the primary button. Omitted for plain actions.
  final IconData? primaryIcon;

  /// Disables the actions and spins the primary button while work is running.
  final bool busy;

  /// Whether this reads as a problem or as an ordinary empty state.
  final ErrorTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.mess;
    final textTheme = Theme.of(context).textTheme;
    final glyphColor = tone == ErrorTone.problem
        ? colors.accent
        : colors.textMuted;

    return Center(
      child: SingleChildScrollView(
        padding: AppTheme.pagePadding.add(const EdgeInsets.symmetric(vertical: 32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colors.accentTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: glyphColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            if (hint != null) ...<Widget>[
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ),
            ],
            if (primaryLabel != null) ...<Widget>[
              const SizedBox(height: 28),
              SizedBox(
                width: 240,
                child: (primaryIcon == null && !busy)
                    ? FilledButton(
                        onPressed: onPrimary,
                        child: Text(primaryLabel!),
                      )
                    : FilledButton.icon(
                        onPressed: onPrimary,
                        icon: busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onAccent,
                                ),
                              )
                            : Icon(primaryIcon, size: 20),
                        label: Text(primaryLabel!),
                      ),
              ),
            ],
            if (secondaryLabel != null) ...<Widget>[
              const SizedBox(height: 10),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// How an [ErrorState] should read.
enum ErrorTone {
  /// Something went wrong.
  problem,

  /// Nothing is wrong, there is simply nothing here.
  neutral,
}
