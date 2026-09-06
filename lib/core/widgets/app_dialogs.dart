import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';

/// Reusable dialog and bottom-sheet presenters.
class AppDialogs {
  const AppDialogs._();

  /// Confirmation dialog returning `true` when the user confirms.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData icon = Symbols.help_rounded,
    Color? accent,
    bool destructive = false,
  }) async {
    final ThemeData theme = Theme.of(context);
    final Color color =
        accent ?? (destructive ? AppColors.emergency : theme.colorScheme.primary);

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: color),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: color),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Informational dialog with a single dismiss action.
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Symbols.info_rounded,
    String closeLabel = 'Got it',
  }) {
    final ThemeData theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: Icon(icon, size: 34, color: theme.colorScheme.primary),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(closeLabel),
          ),
        ],
      ),
    );
  }

  /// Generic titled bottom sheet.
  static Future<T?> sheet<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 4,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.headlineSmall),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 18),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        );
      },
    );
  }

  /// Convenience snackbar with consistent styling.
  static void snack(BuildContext context, String message, {IconData? icon}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
