import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../features/notifications/services/official_horn_service.dart';

enum AppFeedbackType { success, warning, error }

class AppFeedback {
  const AppFeedback._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppFeedbackType.success);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, AppFeedbackType.warning);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, AppFeedbackType.error);
  }

  static void showAnnouncement(
    BuildContext context,
    OfficialAnnouncement announcement,
  ) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.campaign_outlined, color: AppTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      announcement.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(announcement.message),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.accent),
          ),
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      );
  }

  static void _show(
    BuildContext context,
    String message,
    AppFeedbackType type,
  ) {
    final scheme = Theme.of(context).colorScheme;
    late final IconData icon;
    late final Color color;
    switch (type) {
      case AppFeedbackType.success:
        icon = Icons.check_circle_outline;
        color = AppTheme.primary;
        break;
      case AppFeedbackType.warning:
        icon = Icons.warning_amber_outlined;
        color = AppTheme.accent;
        break;
      case AppFeedbackType.error:
        icon = Icons.error_outline;
        color = scheme.error;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.horizontal,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withValues(alpha: 0.7)),
          ),
          backgroundColor: scheme.surfaceContainerHighest,
          elevation: 8,
        ),
      );
  }
}
