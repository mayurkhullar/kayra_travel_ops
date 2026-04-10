import 'package:flutter/material.dart';

class AppDialogs {
  const AppDialogs._();

  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return _showMessageDialog(
      context,
      title: title,
      message: message,
      icon: Icons.info_outline,
      iconColor: Colors.blue.shade700,
    );
  }

  static Future<void> showSuccess(
    BuildContext context, {
    String title = 'Success',
    required String message,
  }) {
    return _showMessageDialog(
      context,
      title: title,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: Colors.green.shade700,
    );
  }

  static Future<void> showError(
    BuildContext context, {
    String title = 'Something went wrong',
    required String message,
  }) {
    return _showMessageDialog(
      context,
      title: title,
      message: message,
      icon: Icons.error_outline,
      iconColor: Colors.red.shade700,
    );
  }

  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDestructive ? Colors.red.shade700 : null,
                foregroundColor: isDestructive ? Colors.white : null,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  static Future<void> _showMessageDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
