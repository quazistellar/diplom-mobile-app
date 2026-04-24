import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:unireax_mobile_diplom/models/course.dart';
import 'package:unireax_mobile_diplom/screens/post_screen.dart';
import '../providers/progress_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../models/assignment.dart';
import '../models/test.dart';
import '../models/progress.dart';
import '../utils/snackbar_helper.dart';
import '../utils/formatters.dart';
import '../utils/file_helper.dart';
import 'assignment_detail_screen.dart';
import 'test_screen.dart';
import 'test_results_screen.dart';
import 'dart:io';

/// данный класс отображает экран материалов курса
class CourseMaterialsScreen extends StatefulWidget {
  final int courseId;
  
  const CourseMaterialsScreen({Key? key, required this.courseId}) : super(key: key);
  
  @override
  State<CourseMaterialsScreen> createState() => _CourseMaterialsScreenState();
}

class _CourseMaterialsScreenState extends State<CourseMaterialsScreen> with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();
  
  late TabController _tabController;
  bool _isLoading = true;
  Course? _course;
  List<LectureWithMaterials> _materialsByLecture = [];
  String? _errorMessage;
  int _totalProgress = 0;
  Map<String, bool> _downloadingFiles = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourseMaterials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// данный метод загружает материалы курса
  Future<void> _loadCourseMaterials() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      setState(() {
        _errorMessage = 'Требуется авторизация';
        _isLoading = false;
      });
      return;
    }

    try {
      if (!await _apiClient.isAuthenticated()) {
        setState(() {
          _errorMessage = 'Требуется авторизация';
          _isLoading = false;
        });
        return;
      }
      
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      await progressProvider.loadCourseMaterials(widget.courseId);
      
      setState(() {
        _materialsByLecture = progressProvider.courseMaterials;
        _course = progressProvider.currentCourse;
        _isLoading = false;
        _errorMessage = null;
      });
      
      _calculateProgress();
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки материалов курса: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// данный метод рассчитывает прогресс по курсу
  void _calculateProgress() {
    int completedAssignments = 0;
    int totalAssignments = 0;
    int completedTests = 0;
    int totalTests = 0;
    
    for (final material in _materialsByLecture) {
      for (final assignment in material.assignments) {
        totalAssignments++;
        if (assignment.isCompleted()) {
          completedAssignments++;
        }
      }
      
      for (final test in material.tests) {
        totalTests++;
        if (test.isPassed) {
          completedTests++;
        }
      }
    }
    
    int totalItems = totalAssignments + totalTests;
    int completedItems = completedAssignments + completedTests;
    
    if (totalItems > 0) {
      _totalProgress = ((completedItems / totalItems) * 100).round();
    } else {
      _totalProgress = 0;
    }
    
    if (mounted) setState(() {});
  }

  /// данный метод показывает диалог со ссылкой на встречу
  void _showMeetingLinkDialog(String? meetingLink, String courseName) {
    final theme = Theme.of(context);
    final bool hasLink = meetingLink != null && meetingLink.isNotEmpty;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.video_call, color: theme.primaryColor),
            const SizedBox(width: 8),
            const Text('Ссылка на встречу'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasLink)
              Column(
                children: [
                  Icon(Icons.link_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Ссылка на видео-встречу пока не добавлена',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Пожалуйста, обратитесь к преподавателю или методисту',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: theme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SelectableText(
                            meetingLink,
                            style: TextStyle(
                              color: theme.primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Нажмите на ссылку выше, чтобы скопировать её, или используйте кнопки ниже',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
        actions: [
          if (hasLink) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _copyMeetingLink(meetingLink);
              },
              child: const Text('Скопировать'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openMeetingLink(meetingLink);
              },
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Открыть'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  /// данный метод копирует ссылку на встречу
  Future<void> _copyMeetingLink(String link) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));
      SnackBarHelper.showSuccess(context, 'Ссылка скопирована в буфер обмена');
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка копирования ссылки');
    }
  }

  /// данный метод открывает ссылку на встречу в браузере
  Future<void> _openMeetingLink(String link) async {
    try {
      if (Platform.isWindows) {
        await Process.run('start', [link], runInShell: true);
      } else {
        SnackBarHelper.showInfo(context, 'Ссылка скопирована. Откройте её в браузере.');
        await Clipboard.setData(ClipboardData(text: link));
      }
    } catch (e) {
      SnackBarHelper.showWarning(context, 'Не удалось открыть ссылку. Скопируйте её вручную.');
    }
  }

  /// данный метод скачивает и открывает файл лекции
  Future<void> _downloadAndOpenLectureFile(String? filePath, String lectureName) async {
    if (filePath == null || filePath.isEmpty) {
      SnackBarHelper.showWarning(context, 'Файл не найден');
      return;
    }

    final fullUrl = _apiClient.getImageUrl(filePath);
    final fileName = _extractFileName(filePath, lectureName);
    final fileKey = '$fullUrl-$fileName';

    if (_downloadingFiles[fileKey] == true) {
      SnackBarHelper.showInfo(context, 'Файл уже скачивается');
      return;
    }

    setState(() => _downloadingFiles[fileKey] = true);

    try {
      final savePath = await FileHelper.downloadFile(
        fileUrl: fullUrl,
        fileName: fileName,
        subFolder: 'Lectures',
        onProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toInt();
            print('Скачивание: $progress%');
          }
        },
      );

      if (savePath == null) {
        throw Exception('Не удалось скачать файл');
      }

      setState(() => _downloadingFiles[fileKey] = false);

      FileHelper.showFileActionDialog(
        context: context,
        filePath: savePath,
        fileName: fileName,
        title: 'Файл загружен',
        onShare: () => _shareFile(savePath, fileName, lectureName),
      );

    } catch (e) {
      setState(() => _downloadingFiles[fileKey] = false);
      print('Ошибка скачивания: $e');
      SnackBarHelper.showError(context, 'Ошибка скачивания файла: ${e.toString()}');
    }
  }

  /// данный метод открывает лекцию онлайн
  Future<void> _openLectureOnline(String? filePath, String lectureName) async {
    if (filePath == null || filePath.isEmpty) {
      SnackBarHelper.showWarning(context, 'Файл не найден');
      return;
    }

    final fullUrl = _apiClient.getImageUrl(filePath);
    
    try {
      SnackBarHelper.showInfo(context, 'Открываю лекцию...');
      
      await Clipboard.setData(ClipboardData(text: fullUrl));
      _showUrlDialog(fullUrl);
    } catch (e) {
      print('Ошибка открытия лекции: $e');
      SnackBarHelper.showWarning(context, 'Не удалось открыть лекцию. Попробуйте скачать файл.');
    }
  }

  /// данный метод показывает диалог с URL лекции
  void _showUrlDialog(String url) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor,
          title: const Text('Открыть лекцию'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_browser, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Ссылка на лекцию скопирована',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Вставьте ссылку в браузере или откройте её по кнопке ниже',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (Platform.isWindows) {
                  _openInBrowserWindows(url);
                }
              },
              child: const Text('Открыть в браузере'),
            ),
          ],
        );
      },
    );
  }

  /// данный метод открывает ссылку в браузере Windows
  Future<void> _openInBrowserWindows(String url) async {
    try {
      await Process.run('start', [url], runInShell: true);
    } catch (e) {
      print('Ошибка открытия в браузере Windows: $e');
      SnackBarHelper.showWarning(context, 'Не удалось открыть в браузере. Скопируйте ссылку вручную.');
    }
  }

  /// данный метод извлекает имя файла из пути
  String _extractFileName(String filePath, String lectureName) {
    try {
      final uri = Uri.parse(filePath);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        String fileName = pathSegments.last;
        
        final cleanLectureName = lectureName
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(' ', '_')
            .substring(0, lectureName.length > 30 ? 30 : lectureName.length);
        
        final fileExtension = fileName.contains('.') 
            ? fileName.substring(fileName.lastIndexOf('.'))
            : '';
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        return '${cleanLectureName}_$timestamp$fileExtension';
      }
    } catch (e) {
      print('Ошибка извлечения имени файла: $e');
    }
    
    return 'lecture_${DateTime.now().millisecondsSinceEpoch}${filePath.contains('.') ? filePath.substring(filePath.lastIndexOf('.')) : '.pdf'}';
  }

  /// данный метод отправляет файл через share
  Future<void> _shareFile(String filePath, String fileName, String lectureName) async {
    try {
      await FileHelper.shareFile(
        filePath,
        text: 'Лекция: $lectureName\n\nФайл из курса: ${_course?.name ?? 'Учебный курс'}',
      );
    } catch (e) {
      print('Ошибка при попытке поделиться: $e');
      SnackBarHelper.showError(context, 'Ошибка при попытке поделиться файлом');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = themeManager.currentTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation ?? 4,
        title: _buildAppBarTitle(theme),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Лекции'),
            Tab(icon: Icon(Icons.assignment), text: 'Работы'),
            Tab(icon: Icon(Icons.quiz), text: 'Тесты'),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.hintColor,
          indicatorColor: theme.colorScheme.primary,
        ),
        actions: [
          if (_course?.meetingLink != null && _course!.meetingLink!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.video_call, color: theme.colorScheme.primary),
              onPressed: () => _showMeetingLinkDialog(_course?.meetingLink, _course?.name ?? 'Курс'),
              tooltip: 'Ссылка на встречу',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _loadCourseMaterials,
            tooltip: 'Обновить',
          ),
          IconButton(
          icon: Icon(Icons.comment, color: theme.colorScheme.primary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostsScreen(
                  courseId: widget.courseId,
                  courseName: _course?.name ?? 'Курс',
                  isTeacher: false,
                ),
              ),
            );
          },
          tooltip: 'Объявления',
        ),
        ],
      ),
      body: _buildBody(theme),
      floatingActionButton: _buildProgressFAB(theme),
    );
  }

  /// данный метод создает заголовок AppBar
  Widget _buildAppBarTitle(ThemeData theme) {
    if (_course != null) {
      return Text(
        _course!.name.length > 30 ? '${_course!.name.substring(0, 30)}...' : _course!.name,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.onSurface,
        ),
      );
    }
    
    return Text(
      'Материалы курса',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  /// данный метод создает тело экрана
  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Ошибка загрузки', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_errorMessage!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadCourseMaterials, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (_materialsByLecture.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_outlined, size: 64, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Материалы курса пока не добавлены', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Обратитесь к преподавателю за дополнительной информацией',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildLecturesTab(_materialsByLecture, theme),
        _buildAssignmentsTab(_materialsByLecture, theme),
        _buildTestsTab(_materialsByLecture, theme),
      ],
    );
  }

  /// данный метод создает вкладку с лекциями
  Widget _buildLecturesTab(List<LectureWithMaterials> materialsByLecture, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: materialsByLecture.length,
      itemBuilder: (context, index) {
        final material = materialsByLecture[index];
        final lecture = material.lecture;
        
        final fileKey = lecture.documentPath != null 
            ? '${_apiClient.getImageUrl(lecture.documentPath)}-${lecture.name}'
            : null;
        final isDownloading = fileKey != null && _downloadingFiles[fileKey] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Text(
                lecture.order.toString(),
                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              lecture.name,
              style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              'Лекция ${lecture.order}',
              style: theme.textTheme.bodySmall,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lecture.content ?? 'Содержание отсутствует',
                      style: theme.textTheme.bodyMedium,
                    ),
                    
                    if (lecture.documentPath != null && lecture.documentPath!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: isDownloading 
                                  ? null 
                                  : () => _downloadAndOpenLectureFile(lecture.documentPath, lecture.name),
                              icon: isDownloading 
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.download),
                              label: Text(isDownloading ? 'Скачивается...' : 'Скачать лекцию'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                disabledBackgroundColor: theme.primaryColor.withOpacity(0.5),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            OutlinedButton.icon(
                              onPressed: () => _openLectureOnline(lecture.documentPath, lecture.name),
                              icon: const Icon(Icons.visibility),
                              label: const Text('Открыть лекцию'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.secondary,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// данный метод создает вкладку с заданиями
  Widget _buildAssignmentsTab(List<LectureWithMaterials> materialsByLecture, ThemeData theme) {
    final allAssignments = materialsByLecture
        .expand((material) => material.assignments)
        .toList();

    if (allAssignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Практические задания отсутствуют', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Все задания будут появляться здесь по мере добавления',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allAssignments.length,
      itemBuilder: (context, index) {
        final assignment = allAssignments[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignmentDetailScreen(
                    courseId: widget.courseId,
                    assignmentId: assignment.id,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          assignment.name,
                          style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w900),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: assignment.getStatusColor(),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          assignment.getStatusText(),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    assignment.description ?? 'Описание отсутствует',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (assignment.deadline != null)
                        _buildDetailChip(
                          icon: Icons.calendar_today,
                          text: 'Срок: ${Formatters.formatDate(assignment.deadline!.toIso8601String())}',
                          color: assignment.isOverdue ? Colors.red : null,
                          theme: theme,
                        ),
                      
                      if (assignment.maxScore != null)
                        _buildDetailChip(
                          icon: Icons.score,
                          text: 'Макс. балл: ${assignment.maxScore}',
                          theme: theme,
                        ),
                      
                      if (assignment.userStatus?.score != null && assignment.maxScore != null)
                        _buildDetailChip(
                          icon: Icons.grade,
                          text: 'Баллы: ${assignment.userStatus!.score}/${assignment.maxScore}',
                          color: assignment.isCompleted() ? Colors.green : 
                                assignment.feedback != null ? Colors.orange : Colors.blue,
                          theme: theme,
                        ),
                      
                      _buildDetailChip(
                        icon: Icons.grading,
                        text: Formatters.getGradingTypeName(assignment.gradingType),
                        theme: theme,
                      ),
                      
                      if (assignment.passingScore != null && assignment.gradingType == 'points')
                        _buildDetailChip(
                          icon: Icons.trending_up,
                          text: 'Проходной: ${assignment.passingScore} баллов',
                          color: Colors.green,
                          theme: theme,
                        ),
                      
                      if (assignment.userStatus?.attemptNumber != null)
                        _buildDetailChip(
                          icon: Icons.repeat,
                          text: 'Попытка: ${assignment.userStatus!.attemptNumber}',
                          theme: theme,
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AssignmentDetailScreen(
                                  courseId: widget.courseId,
                                  assignmentId: assignment.id,
                                ),
                              ),
                            );
                          },
                          child: const Text('Подробнее'),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      if (assignment.canSubmit && !assignment.isCompleted() && assignment.getStatusText() != 'Отклонено')
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AssignmentDetailScreen(
                                  courseId: widget.courseId,
                                  assignmentId: assignment.id,
                                ),
                              ),
                            );
                          },
                          child: Text(assignment.getStatusText() == 'На доработке' ? 'Доработать' : 'Сдать работу'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// данный метод создает вкладку с тестами
  Widget _buildTestsTab(List<LectureWithMaterials> materialsByLecture, ThemeData theme) {
    final allTests = materialsByLecture
        .expand((material) => material.tests)
        .toList();

    if (allTests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Тесты отсутствуют', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Все тесты будут появляться здесь по мере добавления',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allTests.length,
      itemBuilder: (context, index) {
        final test = allTests[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        test.name,
                        style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w900),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: test.getStatusColor(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        test.getStatusText(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                
                if (test.description != null && test.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      test.description!,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (test.isFinal)
                      _buildDetailChip(
                        icon: Icons.flag,
                        text: 'Финальный тест',
                        color: Colors.orange,
                        theme: theme,
                      ),
                    
                    _buildDetailChip(
                      icon: Icons.format_list_bulleted,
                      text: test.gradingForm == 'points' ? 'По баллам' : 'Зачёт/незачёт',
                      theme: theme,
                    ),
                    
                    if (test.passingScore != null && test.gradingForm == 'points')
                      _buildDetailChip(
                        icon: Icons.score,
                        text: 'Проходной: ${test.passingScore} баллов',
                        theme: theme,
                      ),
                    
                    if (test.maxAttempts != null)
                      _buildDetailChip(
                        icon: Icons.repeat,
                        text: 'Попыток: ${test.maxAttempts}',
                        theme: theme,
                      ),
                    
                   if (test.userResult != null && test.maxScore != null)
                  _buildDetailChip(
                    icon: Icons.score,
                    text: 'Набрано баллов за тест: ${test.userResult!.finalScore}',
                    color: test.isPassed ? Colors.green : Colors.red,
                    theme: theme,
                  ),
                    
                    if (test.userResult != null && test.userResult!.completionDate != null)
                      _buildDetailChip(
                        icon: Icons.access_time,
                        text: Formatters.formatDate(test.userResult!.completionDate!.toIso8601String()),
                        theme: theme,
                      ),
                    
                    if (test.attemptsLeft > 0 && !test.isPassed)
                      _buildDetailChip(
                        icon: Icons.hourglass_empty,
                        text: 'Осталось: ${test.attemptsLeft}',
                        color: Colors.blue,
                        theme: theme,
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                if (test.isActive && test.canAttempt)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TestScreen(
                            courseId: widget.courseId,
                            testId: test.id,
                          ),
                        ),
                      );
                    },
                    child: Text(test.userResult == null ? 'Начать тест' : 'Пройти еще раз'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                if (test.userResult != null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
                              final attempts = await progressProvider.getTestAttempts(widget.courseId, test.id);
                              _showTestAttemptsDialog(attempts, test);
                            } catch (e) {
                              print('Ошибка загрузки попыток: $e');
                              SnackBarHelper.showError(context, 'Ошибка загрузки попыток');
                            }
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('История попыток'),
                        ),
                      ),
                    ],
                  ),
                
                if (!test.isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Тест временно недоступен',
                      style: theme.textTheme.bodySmall!.copyWith(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// данный метод создает FAB с прогрессом
  Widget _buildProgressFAB(ThemeData theme) {
    return FloatingActionButton.extended(
      onPressed: () => _showProgressDialog(theme),
      icon: const Icon(Icons.timeline),
      label: Text('$_totalProgress%'),
      backgroundColor: theme.primaryColor,
      foregroundColor: Colors.white,
    );
  }

  /// данный метод создает чип с деталями
  Widget _buildDetailChip({
    required IconData icon,
    required String text,
    Color? color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: color != null ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? theme.colorScheme.secondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: color ?? theme.colorScheme.secondary),
          ),
        ],
      ),
    );
  }

  /// данный метод показывает диалог с прогрессом
  void _showProgressDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Прогресс курса',
            style: (theme.textTheme.titleLarge ?? theme.textTheme.headlineSmall ?? const TextStyle(fontSize: 20))
                .copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 250,
                height: 250, 
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 260, 
                      height: 260,
                      child: CircularProgressIndicator(
                        value: _totalProgress / 100,
                        strokeWidth: 12, 
                        backgroundColor: theme.colorScheme.surface,
                        color: theme.primaryColor,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_totalProgress%',
                          style: (theme.textTheme.displayLarge ?? const TextStyle(fontSize: 44))
                              .copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'завершено',
                          style: (theme.textTheme.titleLarge ?? const TextStyle(fontSize: 18))
                              .copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              if (_course != null)
                Text(
                  _course!.name,
                  style: theme.textTheme.titleLarge ?? const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProgressStat(
                    icon: Icons.menu_book,
                    count: _materialsByLecture.length,
                    label: 'Лекции',
                    theme: theme,
                  ),
                  _buildProgressStat(
                    icon: Icons.assignment,
                    count: _materialsByLecture.fold(0, (sum, m) => sum + m.assignments.length),
                    label: 'Работы',
                    theme: theme,
                  ),
                  _buildProgressStat(
                    icon: Icons.quiz,
                    count: _materialsByLecture.fold(0, (sum, m) => sum + m.tests.length),
                    label: 'Тесты',
                    theme: theme,
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              Divider(color: theme.dividerColor),
              
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProgressStatItem(
                    label: 'Выполнено',
                    count: '$_totalProgress%',
                    color: Colors.green,
                    theme: theme,
                  ),
                  _buildProgressStatItem(
                    label: 'Осталось',
                    count: '${100 - _totalProgress}%',
                    color: Colors.orange,
                    theme: theme,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Закрыть',
                  style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// данный метод создает виджет статистики прогресса
  Widget _buildProgressStat({
    required IconData icon,
    required int count,
    required String label,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: theme.primaryColor),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall!.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }

  /// данный метод создает элемент статистики
  Widget _buildProgressStatItem({
    required String label,
    required String count,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Text(
          count,
          style: theme.textTheme.titleMedium!.copyWith(color: color, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall!.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }

  /// данный метод показывает диалог с историей попыток теста
  void _showTestAttemptsDialog(Map<String, dynamic> attemptsData, Test test) {
    final attempts = attemptsData['attempts'] as List? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('История попыток'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                test.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (attempts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Нет завершенных попыток',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...attempts.map<Widget>((attempt) {
                  final isPassed = test.gradingForm == 'points'
                      ? (attempt['percentage'] ?? 0) >= (test.passingScore ?? 50)
                      : attempt['is_passed'] == true;
                  
                  final totalScore = attempt['total_score'] ?? 0;
                  final maxScore = attempt['max_score'] ?? 1; 
                  final correctAnswers = attempt['correct_answers'] ?? 0;
                  final totalQuestions = attempt['total_questions'] ?? 0;
                  
                  String scoreText;
                  if (test.gradingForm == 'points') {
                    if (totalQuestions > 0) {
                      final percentage = (correctAnswers / totalQuestions * 100).toStringAsFixed(1);
                      scoreText = '$correctAnswers/$totalQuestions правильных ($percentage%)';
                    } else {
                      scoreText = 'Нет данных';
                    }
                  } else {
                    scoreText = attempt['is_passed'] == true ? 'Зачтено' : 'Не зачтено';
                  }
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isPassed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          isPassed ? Icons.check : Icons.close,
                          color: isPassed ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text('Попытка ${attempt['attempt_number'] ?? 1}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scoreText,
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (test.gradingForm == 'points')
                            Text(
                              'Набрано баллов: $totalScore',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          Text(
                            'Время: ${attempt['time_spent'] ?? 0} сек',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPassed ? 'Сдано' : 'Не сдано',
                            style: TextStyle(
                              fontSize: 12,
                              color: isPassed ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: attempt['id'] != null
                          ? IconButton(
                              icon: const Icon(Icons.visibility, size: 20),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TestResultScreen(
                                      testResultId: attempt['id'],
                                      courseId: widget.courseId,
                                      testId: test.id,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Просмотреть детали',
                            )
                          : null,
                      onTap: attempt['id'] != null
                          ? () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TestResultScreen(
                                    testResultId: attempt['id'],
                                    courseId: widget.courseId,
                                    testId: test.id,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}