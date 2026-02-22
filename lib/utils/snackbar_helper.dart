import 'package:flutter/material.dart';

class SnackBarHelper {
  static void show({
    required BuildContext context,
    required String message,
    required Color color,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      color: Colors.red,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      color: Colors.green,
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      color: Colors.blue,
    );
  }

  static void showWarning(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      color: Colors.orange,
    );
  }
}