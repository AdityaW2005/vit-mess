import 'package:flutter/material.dart';

import '../core/constants/strings.dart';
import '../core/theme/app_theme.dart';
import '../models/menu.dart';

/// Asks whether a spreadsheet for a month that has already passed should
/// still replace the cached menu.
///
/// Returns `false` when the student backs out or dismisses the dialog, so the
/// safe answer is the one they get by doing nothing. Shared by all four import
/// entry points — Today, Week, Search and Settings — so the warning reads the
/// same wherever the file was chosen.
Future<bool> confirmStaleMenuImport(
  BuildContext context,
  StaleMenuImport candidate,
) async {
  final colors = Theme.of(context).extension<MessColors>() ?? MessColors.dark;

  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;

      return AlertDialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: BorderSide(color: colors.hairline),
        ),
        icon: Icon(
          Icons.event_busy_rounded,
          size: 28,
          color: colors.accent,
        ),
        title: Text(
          Strings.staleImportTitle,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          Strings.staleImportBody(
            month: candidate.month,
            currentMonth: candidate.currentMonth,
          ),
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
          // Keeping what they have is the safe answer, so it reads first and
          // carries the accent.
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              candidate.replacesExistingMenu
                  ? Strings.staleImportCancel
                  : Strings.staleImportDismiss,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
            child: const Text(Strings.staleImportAccept),
          ),
        ],
      );
    },
  );

  return accepted ?? false;
}
