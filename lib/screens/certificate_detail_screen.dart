import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/certificate_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/progress_provider.dart';
import '../models/certificate.dart';
import '../models/course.dart';
import '../utils/snackbar_helper.dart';

/// данный класс отображает экран деталей сертификата
class CertificateDetailScreen extends StatefulWidget {
  final Map<String, dynamic> certificate;
  final Map<String, dynamic> course;
  
  const CertificateDetailScreen({
    Key? key,
    required this.certificate,
    required this.course,
  }) : super(key: key);

  @override
  State<CertificateDetailScreen> createState() => _CertificateDetailScreenState();
}

class _CertificateDetailScreenState extends State<CertificateDetailScreen> {
  bool _isDownloading = false;
  bool _isRegenerating = false;
  late Certificate _certificate;
  late Course _course;
  Map<String, dynamic>? _scoreData;

  @override
  void initState() {
    super.initState();
    _certificate = Certificate.fromJson(widget.certificate);
    _course = Course.fromJson(widget.course);
    _loadScoreData();
  }

  /// данная функция загружает данные о баллах за курс
  Future<void> _loadScoreData() async {
    try {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final scoreData = await progressProvider.getCourseScore(_course.id);
      if (mounted) {
        setState(() {
          _scoreData = scoreData;
        });
      }
    } catch (e) {
      print('Ошибка загрузки баллов: $e');
    }
  }

  /// данная функция обновляет сертификат с актуальной статистикой
  Future<void> _regenerateCertificate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Обновить сертификат'),
        content: const Text('Вы уверены, что хотите обновить сертификат с актуальной статистикой?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Обновить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRegenerating = true);

    try {
      final certificateProvider = Provider.of<CertificateProvider>(
        context, 
        listen: false
      );
      
      final result = await certificateProvider.regenerateCertificate(_certificate.id);
      
      if (!mounted) return;
      
      if (result['certificate'] != null) {
        _certificate = Certificate.fromJson(result['certificate']);
      }
      
      await _loadScoreData();
      
      SnackBarHelper.showSuccess(context, 'Сертификат обновлён с актуальной статистикой!');
      
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Ошибка обновления: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  /// данная функция скачивает сертификат
  Future<void> _downloadCertificate() async {
    setState(() => _isDownloading = true);

    try {
      final certificateProvider = Provider.of<CertificateProvider>(
        context, 
        listen: false
      );
      
      final certificateId = _certificate.id;
      final filePath = await certificateProvider.downloadCertificate(certificateId);
      
      if (!mounted) return;
      
      _showFileActionDialog(filePath);
      
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Ошибка скачивания: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  /// данная функция открывает файл сертификата
  Future<void> _openCertificate(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Не удалось открыть файл: ${result.message}');
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Ошибка открытия файла: $e');
    }
  }

  /// данная функция показывает диалог действий с файлом
  void _showFileActionDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Сертификат загружен',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'Сертификат успешно сохранен',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _certificate.certificateNumber,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openCertificate(filePath);
              },
              icon: const Icon(Icons.visibility),
              label: const Text('Открыть'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = themeManager.currentTheme;
    
    final totalEarned = _scoreData?['total_earned'] ?? 0;
    final totalMax = _scoreData?['total_max'] ?? 0;
    final percentage = _scoreData?['percentage'] ?? 0;
    final withHonors = _scoreData?['with_honors'] ?? false;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation ?? 4,
        title: const Text(
          'Сертификат',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: _isRegenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRegenerating ? null : _regenerateCertificate,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            onPressed: _isDownloading ? null : _downloadCertificate,
            tooltip: 'Скачать',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF7B7FD5),
                      Color(0xFF5864F1),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'UNIREAX',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    const Text(
                      'СЕРТИФИКАТ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    const Text(
                      'Настоящим удостоверяется, что',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      _course.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'успешно завершил(а) курс',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      _course.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            'Набрано баллов: $totalEarned из $totalMax',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Процент выполнения: ${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (withHonors)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: const Text(
                          'С ОТЛИЧИЕМ!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Номер сертификата: ${_certificate.certificateNumber}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Дата выдачи: ${_certificate.formattedDate}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    const Column(
                      children: [
                        SizedBox(height: 20),
                        Text(
                          '____________________',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          'Директор UNIREAX',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Это предпросмотр информации на сертификате. Для получения официальной версии с подписью скачайте сертификат на своё устройство.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Информация о курсе',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      Icons.school,
                      'Название',
                      _course.name,
                    ),
                    _buildInfoRow(
                      context,
                      Icons.category,
                      'Категория',
                      _course.category?.name ?? 'Не указана',
                    ),
                    _buildInfoRow(
                      context,
                      Icons.timer,
                      'Часов',
                      '${_course.hours} ч',
                    ),
                    _buildInfoRow(
                      context,
                      Icons.star,
                      'Набрано баллов',
                      '$totalEarned из $totalMax',
                    ),
                    _buildInfoRow(
                      context,
                      Icons.percent,
                      'Процент выполнения',
                      '${percentage.toStringAsFixed(1)}%',
                    ),
                    if (withHonors)
                      _buildInfoRow(
                        context,
                        Icons.emoji_events,
                        'Отличие',
                        'С ОТЛИЧИЕМ!',
                        valueColor: const Color(0xFFFFD700),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _downloadCertificate,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isDownloading ? 'Скачивание...' : 'Скачать'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Назад'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// данный метод создает виджет строки с информацией
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}