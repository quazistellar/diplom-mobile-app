import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' show MultipartFile, Dio, FormData;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../providers/progress_provider.dart';
import '../providers/theme_provider.dart';
import '../models/assignment.dart';
import '../models/assignment_attempt.dart';
import '../utils/formatters.dart';
import '../utils/snackbar_helper.dart';

/// класс отображает экран подробной информации практической работы
class AssignmentDetailScreen extends StatefulWidget {
  final int courseId;
  final int assignmentId;

  const AssignmentDetailScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  
  Map<String, dynamic>? _assignmentData;
  Map<String, dynamic>? _attemptsData;
  bool _isLoading = true;
  bool _isLoadingAttempts = false;
  String? _errorMessage;
  
  List<PlatformFile> _selectedFiles = [];
  List<int> _filesToRemove = [];
  bool _isSubmitting = false;
  bool _isEditing = false;
  int? _editingAttemptId;
  Map<String, dynamic>? _editingAttemptData;
  
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editCommentController.dispose();
    super.dispose();
  }

  /// данная функция загружает детали задания и попытки
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadAssignmentDetails(),
        _loadAttempts(),
      ]);
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// данная функция загружает детали задания
  Future<void> _loadAssignmentDetails() async {
    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/listener/progress/${widget.courseId}/assignments/${widget.assignmentId}/'
      );

      setState(() => _assignmentData = data);
    } catch (e) {
      throw Exception('Ошибка загрузки деталей задания: $e');
    }
  }

  /// данная функция загружает попытки выполнения задания
  Future<void> _loadAttempts() async {
    setState(() => _isLoadingAttempts = true);
    
    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/listener/progress/${widget.courseId}/assignments/${widget.assignmentId}/attempts/'
      );

      setState(() {
        _attemptsData = data;
        _isLoadingAttempts = false;
      });
    } catch (e) {
      setState(() => _isLoadingAttempts = false);
      print('Ошибка загрузки попыток: $e');
    }
  }

  /// данная функция выбирает файлы для загрузки
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.files;

        if (_selectedFiles.length + newFiles.length > 10) {
          SnackBarHelper.showWarning(context, 'Максимум 10 файлов');
          return;
        }

        int totalSize = _selectedFiles.fold<int>(0, (s, f) => s + (f.size));
        totalSize += newFiles.fold<int>(0, (s, f) => s + (f.size));

        if (totalSize > 100 * 1024 * 1024) {
          SnackBarHelper.showError(context, 'Общий размер превышает 100 МБ');
          return;
        }

        setState(() => _selectedFiles.addAll(newFiles));
      }
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка выбора файлов: $e');
    }
  }

  /// данная функция отправляет задание на проверку
  Future<void> _submitAssignment() async {
    if (_selectedFiles.isEmpty) {
      SnackBarHelper.showWarning(context, 'Добавьте хотя бы один файл');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final filesMultipart = _selectedFiles.map((file) {
        return MultipartFile.fromFileSync(file.path!, filename: file.name);
      }).toList();

      final formData = FormData.fromMap({
        'practical_assignment': widget.assignmentId.toString(),
        'comment': _commentController.text.trim(),
        'files': filesMultipart,
      });

      await _apiClient.post(
        '/listener/progress/${widget.courseId}/assignments/${widget.assignmentId}/submit/',
        data: formData,
        isFormData: true,
      );

      SnackBarHelper.showSuccess(context, 'Работа успешно отправлена на проверку');

      setState(() {
        _selectedFiles.clear();
        _commentController.clear();
      });

      await _loadAttempts();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка отправки: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// данная функция обновляет существующую попытку
  Future<void> _updateAttempt(int attemptId) async {
    if (_selectedFiles.isEmpty && 
        _editCommentController.text.isEmpty && 
        _filesToRemove.isEmpty) {
      SnackBarHelper.showWarning(context, 'Нет изменений для сохранения');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final filesMultipart = _selectedFiles.map((file) {
        return MultipartFile.fromFileSync(file.path!, filename: file.name);
      }).toList();

      final formData = FormData.fromMap({
        'comment': _editCommentController.text.trim(),
        'files_to_remove': _filesToRemove.join(','),
      });

      for (var file in filesMultipart) {
        formData.files.add(MapEntry('files', file));
      }

      await _apiClient.put(
        '/listener/progress/${widget.courseId}/assignments/${widget.assignmentId}/attempt/$attemptId/',
        data: formData,
        isFormData: true,
      );

      SnackBarHelper.showSuccess(context, 'Попытка успешно обновлена');

      setState(() {
        _isEditing = false;
        _editingAttemptId = null;
        _editingAttemptData = null;
        _selectedFiles.clear();
        _filesToRemove.clear();
        _editCommentController.clear();
      });

      await _loadAttempts();
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка обновления: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// данная функция начинает редактирование попытки
  void _startEditing(Map<String, dynamic> attempt) {
    setState(() {
      _isEditing = true;
      _editingAttemptId = attempt['id'];
      _editingAttemptData = attempt;
      _editCommentController.text = attempt['comment'] ?? '';
      _filesToRemove.clear();
      _selectedFiles.clear();
    });
  }

  /// данная функция отменяет редактирование попытки
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingAttemptId = null;
      _editingAttemptData = null;
      _selectedFiles.clear();
      _filesToRemove.clear();
      _editCommentController.clear();
    });
  }

  /// данная функция переключает состояние удаления файла
  void _toggleFileRemoval(int fileId) {
    setState(() {
      if (_filesToRemove.contains(fileId)) {
        _filesToRemove.remove(fileId);
      } else {
        _filesToRemove.add(fileId);
      }
    });
  }

  /// данная функция скачивает файл преподавателя
  Future<void> _downloadTeacherFile(Map<String, dynamic> file) async {
    try {
      String fileUrl = file['file']?.toString() ?? '';
      if (fileUrl.isEmpty) {
        SnackBarHelper.showWarning(context, 'Ссылка на файл отсутствует');
        return;
      }

      fileUrl = _apiClient.getImageUrl(fileUrl);

      final fileName = file['file_name']?.toString() ??
          'file_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception('Не удалось найти папку Загрузки');

      final savePath = '${directory.path}/$fileName';

      SnackBarHelper.showInfo(context, 'Скачивание начато...');

      final dio = Dio();
      final token = await _apiClient.getToken();
      if (token != null) dio.options.headers['Authorization'] = 'Bearer $token';

      await dio.download(fileUrl, savePath);

      SnackBarHelper.showSuccess(context, 'Файл сохранён: $fileName');

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        SnackBarHelper.showWarning(context, 'Не удалось открыть файл: ${result.message}');
      }
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка скачивания: $e');
    }
  }

  /// данная функция скачивает файл отправленного задания
  Future<void> _downloadSubmissionFile(String fileUrl, String fileName) async {
    try {
      if (fileUrl.isEmpty) {
        SnackBarHelper.showWarning(context, 'Ссылка на файл отсутствует');
        return;
      }

      final fullUrl = _apiClient.getImageUrl(fileUrl);
      
      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception('Не удалось найти папку Загрузки');

      final savePath = '${directory.path}/$fileName';

      SnackBarHelper.showInfo(context, 'Скачивание начато...');

      final dio = Dio();
      final token = await _apiClient.getToken();
      if (token != null) dio.options.headers['Authorization'] = 'Bearer $token';

      await dio.download(fullUrl, savePath);

      SnackBarHelper.showSuccess(context, 'Файл сохранён: $fileName');

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        SnackBarHelper.showWarning(context, 'Не удалось открыть файл: ${result.message}');
      }
    } catch (e) {
      SnackBarHelper.showError(context, 'Ошибка скачивания: $e');
    }
  }

  /// данная функция проверяет статус оценки задания
  bool _checkAssignmentGrading({
    required String gradingType,
    required dynamic passingScore,
    required dynamic maxScore,
    required dynamic userScore,
    required dynamic feedbackScore,
    required dynamic feedbackIsPassed,
  }) {
    final actualScore = feedbackScore ?? userScore;
    
    if (gradingType == 'points') {
      if (actualScore == null || maxScore == null) return false;
      
      double numericScore = actualScore is int ? actualScore.toDouble() : 
                           actualScore is double ? actualScore : 0;
      double numericMaxScore = maxScore is int ? maxScore.toDouble() : 
                              maxScore is double ? maxScore : 0;
      
      if (numericMaxScore <= 0) return false;
      
      if (passingScore != null) {
        double numericPassingScore = passingScore is int ? passingScore.toDouble() : 
                                    passingScore is double ? passingScore : 0;
        return numericScore >= numericPassingScore;
      } else {
        double halfScore = numericMaxScore * 0.5;
        return numericScore >= halfScore;
      }
    } else if (gradingType == 'pass_fail') {
      if (feedbackIsPassed != null) {
        return feedbackIsPassed == true;
      }
      
      if (actualScore != null && maxScore != null) {
        double numericScore = actualScore is int ? actualScore.toDouble() : 
                             actualScore is double ? actualScore : 0;
        double numericMaxScore = maxScore is int ? maxScore.toDouble() : 
                                maxScore is double ? maxScore : 0;
        
        if (numericMaxScore <= 0) return false;
        
        double percentage = (numericScore / numericMaxScore) * 100;
        return percentage >= 50;
      }
      
      return false;
    }
    
    return false;
  }

  /// данная функция создает виджет статусного бейджа
  Widget _buildStatusBadge(String status, String description, String color) {
    Color badgeColor;
    IconData icon;
    
    switch (color.toLowerCase()) {
      case 'orange':
        badgeColor = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case 'green':
        badgeColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'red':
        badgeColor = Colors.red;
        icon = Icons.timer_off;
        break;
      case 'darkred':
        badgeColor = Colors.red[700]!;
        icon = Icons.block;
        break;
      case 'blue':
        badgeColor = Colors.blue;
        icon = Icons.autorenew;
        break;
      case 'grey':
      default:
        badgeColor = Colors.grey;
        icon = Icons.help_outline;
    }
    
    return Tooltip(
      message: description,
      child: Chip(
        label: Text(status),
        backgroundColor: badgeColor.withOpacity(0.1),
        labelStyle: TextStyle(color: badgeColor, fontWeight: FontWeight.w500),
        avatar: Icon(icon, size: 16, color: badgeColor),
        side: BorderSide(color: badgeColor.withOpacity(0.3)),
      ),
    );
  }

  /// данная функция создает виджет оценки
  Widget _buildGradeWidget(Map<String, dynamic>? feedback, String gradingType, int? maxScore, int? passingScore) {
    if (feedback == null) return const SizedBox();
    
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;
    final score = feedback['score'];
    final isPassed = feedback['is_passed'];
    final feedbackText = feedback['feedback_text'];
    final givenByName = feedback['given_by']?['name'];
    final givenAt = feedback['given_at'];
    
    final bool isCompleted = _checkAssignmentGrading(
      gradingType: gradingType,
      passingScore: passingScore,
      maxScore: maxScore,
      userScore: score,
      feedbackScore: score,
      feedbackIsPassed: isPassed,
    );
    
    Color feedbackColor = isCompleted ? Colors.green[700]! : Colors.red[700]!;
    Color textColor = isDarkTheme ? Colors.white : Colors.black87;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: feedbackColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: feedbackColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback, color: feedbackColor, size: 18),
              const SizedBox(width: 8),
              Text(
                isCompleted ? 'Работа зачтена' : 'Требуется доработка',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: feedbackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          if (gradingType == 'points' && score != null && maxScore != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text('Баллы: $score/$maxScore'),
                      backgroundColor: feedbackColor.withOpacity(0.1),
                      labelStyle: TextStyle(color: feedbackColor, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${(maxScore > 0 ? (score / maxScore * 100) : 0).toStringAsFixed(1)}%)',
                      style: TextStyle(color: feedbackColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                
                if (passingScore != null && gradingType == 'points')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Проходной балл: $passingScore',
                      style: TextStyle(fontSize: 12, color: feedbackColor.withOpacity(0.7)),
                    ),
                  ),
              ],
            )
          else if (gradingType == 'pass_fail')
            Chip(
              label: Text(isCompleted ? 'Зачтено' : 'Не зачтено'),
              backgroundColor: isCompleted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isCompleted ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          
          if (feedbackText?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkTheme ? Colors.black.withOpacity(0.2) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: feedbackColor.withOpacity(0.2)),
              ),
              child: Text(
                feedbackText?.toString() ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            ),
          ],
          
          if (givenByName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Проверил: $givenByName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: feedbackColor.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          if (givenAt != null) ...[
            Text(
              'Дата проверки: ${Formatters.formatDateTime(givenAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// данная функция создает виджет карточки попытки
  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final theme = Theme.of(context);
    final status = attempt['status'] as Map<String, dynamic>? ?? {};
    final files = (attempt['files'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final feedback = attempt['feedback'] as Map<String, dynamic>?;
    final canEdit = status['can_edit'] as bool? ?? false;
    final gradingType = attempt['grading_type'] as String? ?? 'points';
    final maxScore = attempt['max_score'] as int?;
    final passingScore = attempt['passing_score'] as int?;
    final isOverdue = attempt['is_overdue'] as bool? ?? false;
    final score = attempt['score'] as int?;
    final feedbackScore = feedback?['score'];
    final feedbackIsPassed = feedback?['is_passed'];
    
    final isCompleted = _checkAssignmentGrading(
      gradingType: gradingType,
      passingScore: passingScore,
      maxScore: maxScore,
      userScore: score,
      feedbackScore: feedbackScore,
      feedbackIsPassed: feedbackIsPassed,
    );
    
    String displayStatus = status['name'] ?? 'Неизвестно';
    String displayColor = status['color'] ?? 'grey';
    
    if (feedback != null) {
      if (isCompleted) {
        displayStatus = 'Завершено';
        displayColor = 'green';
      } else {
        displayStatus = 'На доработке';
        displayColor = 'orange';
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: canEdit ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
          width: canEdit ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Попытка №${attempt['attempt_number']}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      Formatters.formatDateTime(attempt['submission_date']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusBadge(
                      displayStatus,
                      status['description'] ?? '',
                      displayColor,
                    ),
                    if (isOverdue) ...[
                      const SizedBox(height: 4),
                      Chip(
                        label: const Text('Просрочено'),
                        backgroundColor: Colors.red.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: Colors.red[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            if (attempt['comment']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Комментарий студента:',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  attempt['comment']?.toString() ?? '',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            
            if (files.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Прикрепленные файлы (${files.length}):',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...files.map((file) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Formatters.getFileIconData(file['file_name']?.toString() ?? ''),
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  file['file_name']?.toString() ?? 'Файл',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(Formatters.formatFileSize(file['file_size'])),
                trailing: _isEditing && _editingAttemptId == attempt['id']
                    ? Checkbox(
                        value: _filesToRemove.contains(file['id']),
                        onChanged: (value) => _toggleFileRemoval(file['id']),
                      )
                    : IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _downloadSubmissionFile(
                          file['file_url']?.toString() ?? '',
                          file['file_name']?.toString() ?? 'file',
                        ),
                      ),
              )),
            ],
            
            if (feedback != null) ...[
              const SizedBox(height: 16),
              _buildGradeWidget(feedback, gradingType, maxScore, passingScore),
            ],
            
            if (canEdit && !_isEditing && !isCompleted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _startEditing(attempt),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Редактировать попытку'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Практическая работа')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Загрузка задания...', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Практическая работа')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text('Ошибка загрузки', style: theme.textTheme.titleLarge),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _assignmentData!;
    final assignment = data['assignment'] as Map<String, dynamic>? ?? {};
    final teacherFiles = (data['teacher_files'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final canSubmit = data['can_submit'] as bool? ?? false;
    final attempts = (_attemptsData?['attempts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final assignmentInfo = _attemptsData?['assignment'] as Map<String, dynamic>? ?? {};
    final canSubmitNew = _attemptsData?['can_submit_new'] as bool? ?? true;
    final currentAttemptsCount = _attemptsData?['current_attempts_count'] as int? ?? 0;

    final deadline = assignment['deadline'];
    final isCanPinAfterDeadline = assignment['is_can_pin_after_deadline'] as bool? ?? false;
    final maxScore = assignment['max_score'];
    final passingScore = assignment['passing_score'];
    final gradingType = assignment['grading_type'] ?? 'points';

    bool canActuallySubmit = canSubmit && canSubmitNew;
    if (deadline != null && !isCanPinAfterDeadline) {
      try {
        final deadlineDate = DateTime.parse(deadline);
        if (DateTime.now().isAfter(deadlineDate)) canActuallySubmit = false;
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Практическая работа'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment['practical_assignment_name'] ?? 'Без названия',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      assignment['practical_assignment_description'] ?? 'Описание отсутствует',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    
                    _buildInfoRow(Icons.calendar_today, 'Срок сдачи',
                        Formatters.formatDateTime(assignment['deadline'])),
                    
                    _buildInfoRow(Icons.score, 'Макс. балл',
                        maxScore?.toString() ?? '—'),
                    
                    if (gradingType == 'points' && passingScore != null)
                      _buildInfoRow(
                        Icons.trending_up, 
                        'Проходной балл',
                        passingScore.toString(),
                        Colors.green,
                      ),
                    
                    _buildInfoRow(Icons.grading, 'Тип оценки',
                        Formatters.getGradingTypeName(gradingType)),
                    
                    if (assignment['is_can_pin_after_deadline'] == true)
                      _buildInfoRow(Icons.access_time, 'Можно сдать после срока',
                          'Да', Colors.green),
                    
                    _buildInfoRow(Icons.history, 'Текущие попытки',
                        currentAttemptsCount.toString()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (teacherFiles.isNotEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Материалы преподавателя', style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...teacherFiles.map((file) => ListTile(
                        leading: Icon(Formatters.getFileIconData(file['file_name']?.toString() ?? '')),
                        title: Text(file['file_name'] ?? 'Файл'),
                        subtitle: Text(Formatters.formatFileSize(file['file_size'] ?? 0)),
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _downloadTeacherFile(file),
                        ),
                      )),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('История сдачи', style: theme.textTheme.titleMedium),
                        if (_attemptsData != null) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('$currentAttemptsCount'),
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_isLoadingAttempts)
                      const Center(child: CircularProgressIndicator()),
                    
                    if (!_isLoadingAttempts && attempts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_turned_in,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Пока нет отправленных работ',
                              style: theme.textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Будьте первым, кто отправит выполненное задание!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    
                    if (!_isLoadingAttempts && attempts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...attempts.map((attempt) => Column(
                        children: [
                          _buildAttemptCard(attempt),
                          if (attempt != attempts.last) const SizedBox(height: 16),
                        ],
                      )),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if ((canActuallySubmit && !_isEditing) || _isEditing)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Редактирование попытки №${_editingAttemptData?['attempt_number']}' : 'Отправить работу',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      
                      if (_isEditing && _editingAttemptData != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Статус: ${_editingAttemptData!['status']['name']}',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.blue[700]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _editingAttemptData!['status']['description'],
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 16),

                      if (_isEditing && _filesToRemove.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Отмечено файлов для удаления: ${_filesToRemove.length}',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_selectedFiles.isNotEmpty) ...[
                        ..._selectedFiles.map((f) => ListTile(
                          leading: Icon(Formatters.getFileIconData(f.name)),
                          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(Formatters.formatFileSize(f.size)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => _selectedFiles.remove(f)),
                          ),
                        )),
                        const Divider(height: 32),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Добавить файлы'),
                            ),
                          ),
                          if (_isEditing) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _cancelEditing,
                                icon: const Icon(Icons.close),
                                label: const Text('Отмена'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(color: Colors.red.withOpacity(0.5)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _isEditing ? _editCommentController : _commentController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Комментарий (необязательно)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : _isEditing
                                  ? () => _updateAttempt(_editingAttemptId!)
                                  : _submitAssignment,
                          icon: _isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(_isEditing ? Icons.save : Icons.send),
                          label: Text(_isSubmitting
                              ? 'Отправка...'
                              : _isEditing
                                  ? 'Сохранить изменения'
                                  : 'Отправить на проверку'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (!canActuallySubmit && attempts.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Новая отправка недоступна',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              deadline != null && !isCanPinAfterDeadline
                                  ? 'Срок сдачи истек'
                                  : 'Работа уже проверена или отклонена',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// данная функция создает виджет строки с информацией
  Widget _buildInfoRow(IconData icon, String label, String? value, [Color? valueColor]) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value ?? '—', style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor ?? theme.colorScheme.primary,
          )),
        ],
      ),
    );
  }
}