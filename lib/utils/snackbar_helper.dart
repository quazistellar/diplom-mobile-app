import 'package:flutter/material.dart';

/// данный класс предоставляет вспомогательные методы для отображения уведомлений
class SnackBarHelper {
  /// данная функция показывает уведомление с заданным цветом
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

  /// данная функция показывает уведомление об ошибке
  static void showError(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      color: Colors.red,
    );
  }

  /// данная функция показывает уведомление об успехе
  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      color: Colors.green,
    );
  }

  /// данная функция показывает информационное уведомление
  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      color: Colors.blue,
    );
  }

  /// данная функция показывает предупреждение
  static void showWarning(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      color: Colors.orange,
    );
  }
}