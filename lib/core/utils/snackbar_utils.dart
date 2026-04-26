import 'package:flutter/material.dart';

void showError(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onAction}) {
  if (!context.mounted) return;
  _show(context, message, Colors.redAccent, Icons.error_outline_rounded,
      actionLabel, onAction);
}

void showSuccess(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onAction}) {
  if (!context.mounted) return;
  _show(context, message, Colors.greenAccent,
      Icons.check_circle_outline_rounded, actionLabel, onAction);
}

void _show(BuildContext context, String message, Color color, IconData icon,
    String? actionLabel, VoidCallback? onAction) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: color.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
      duration: const Duration(seconds: 3),
    ),
  );
}
