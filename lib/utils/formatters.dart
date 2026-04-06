import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// данный класс предоставляет утилиты для форматирования данных
class Formatters {
  /// данная функция форматирует дату в формат ДД.ММ.ГГГГ
  static String formatDate(String? date) {
    if (date == null || date.isEmpty) return '—';
    try {
      final d = DateTime.parse(date);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return date;
    }
  }

  /// данная функция форматирует дату и время в формат ДД.ММ.ГГГГ ЧЧ:ММ
  static String formatDateTime(String? date) {
    if (date == null || date.isEmpty) return '—';
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd.MM.yyyy HH:mm').format(d);
    } catch (_) {
      return date;
    }
  }

  /// данная функция форматирует размер файла в удобно читаемый вид
  static String formatFileSize(dynamic size) {
    if (size == null) return '—';
    
    int bytes;
    if (size is int) {
      bytes = size;
    } else if (size is String) {
      bytes = int.tryParse(size) ?? 0;
    } else if (size is double) {
      bytes = size.toInt();
    } else {
      return '—';
    }
    
    if (bytes == 0) return '0 Б';
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / 1048576).toStringAsFixed(1)} МБ';
  }

  /// данная функция форматирует большие числа с суффиксами (k, M)
  static String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  /// данная функция возвращает строковый идентификатор типа файла
  static String getFileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'zip':
      case 'rar':
      case '7z':
        return 'archive';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return 'image';
      case 'xls':
      case 'xlsx':
        return 'excel';
      case 'ppt':
      case 'pptx':
        return 'ppt';
      case 'txt':
        return 'text';
      default:
        return 'file';
    }
  }

  /// данная функция возвращает иконку для типа файла
  static IconData getFileIconData(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_fields;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// данная функция возвращает название типа оценивания
  static String getGradingTypeName(String? type) {
    switch (type) {
      case 'points':
        return 'Балльная система';
      case 'pass_fail':
        return 'Зачёт/Незачёт';
      default:
        return type ?? '—';
    }
  }

  /// данная функция возвращает правильное склонение слова "курс"
  static String getCourseWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'курс';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'курса';
    }
    return 'курсов';
  }
}