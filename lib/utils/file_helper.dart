import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class FileHelper {
  static final ApiClient _apiClient = ApiClient();

  /// скачивание файла
  static Future<String?> downloadFile({
    required String fileUrl,
    required String fileName,
    String? subFolder,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final directory = await _getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Не удалось получить директорию для сохранения');
      }

      final baseDir = Directory('${directory.path}/Unireax');
      if (!await baseDir.exists()) {
        await baseDir.create();
      }

      String saveDir = baseDir.path;
      if (subFolder != null && subFolder.isNotEmpty) {
        final subDir = Directory('$saveDir/$subFolder');
        if (!await subDir.exists()) {
          await subDir.create();
        }
        saveDir = subDir.path;
      }

      final savePath = '$saveDir/$fileName';

      final dio = Dio();
      final token = await _apiClient.getToken();
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }

      await dio.download(
        fileUrl,
        savePath,
        onReceiveProgress: onProgress,
      );

      print('Файл сохранен: $savePath');
      return savePath;
      
    } catch (e) {
      print('Ошибка скачивания файла: $e');
      return null;
    }
  }

  /// получение директории для загрузок в зависимости от платформы
  static Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      return await getDownloadsDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      return await getTemporaryDirectory();
    }
  }

  /// открытие файла
  static Future<void> openFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Не удалось открыть файл: ${result.message}');
      }
    } catch (e) {
      print('❌ Ошибка открытия файла: $e');
      rethrow;
    }
  }

  /// поделиться файлом
  static Future<void> shareFile(String filePath, {String? text}) async {
    try {
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: text);
    } catch (e) {
      print('❌ Ошибка при попытке поделиться: $e');
      rethrow;
    }
  }

  /// диалог с действиями после скачивания 
  static void showFileActionDialog({
    required BuildContext context,
    required String filePath,
    required String fileName,
    required String title,
    VoidCallback? onOpen,
    VoidCallback? onShare,
  }) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download_done, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                fileName,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              const Text(
                'Файл сохранен в папку Unireax',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Закрыть',
                style: TextStyle(color: theme.hintColor),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (onOpen != null) {
                  onOpen();
                } else {
                  openFile(filePath);
                }
              },
              icon: const Icon(Icons.open_in_browser, size: 20),
              label: const Text('Открыть'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            if (onShare != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onShare();
                  },
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('Поделиться'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// получение иконки для типа файла
  static IconData getFileIcon(String fileName) {
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

  /// форматирование размера файла
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 Б';
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / 1048576).toStringAsFixed(1)} МБ';
  }
}