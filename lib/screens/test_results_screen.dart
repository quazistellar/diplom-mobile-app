import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/theme_provider.dart';
import '../models/test.dart';
import '../utils/snackbar_helper.dart';

class TestResultScreen extends StatefulWidget {
  final int testResultId;
  final int courseId;
  final int testId;
  
  const TestResultScreen({
    Key? key,
    required this.testResultId,
    required this.courseId,
    required this.testId,
  }) : super(key: key);
  
  @override
  State<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends State<TestResultScreen> {
  Map<String, dynamic>? _resultData;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadResultDetails();
  }
  
  Future<void> _loadResultDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final data = await progressProvider.getTestResultDetails(widget.testResultId);
      
      setState(() {
        _resultData = data;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }
  
  void _goBack() {
    Navigator.pop(context);
  }
  
  String _getTestStatus(Map<String, dynamic> testResult) {
    final gradingForm = testResult['grading_form']?.toString().toLowerCase();
    final totalScore = testResult['total_score'] ?? 0;
    final maxScore = testResult['max_score'] ?? 1;
    final isPassed = testResult['is_passed'];
    final passingScore = testResult['passing_score'] ?? 0;
    
    if (isPassed != null) {
      return isPassed ? 'Зачтено' : 'Не зачтено';
    }
    
    if (gradingForm == 'points') {
      if (maxScore > 0) {
        final percentage = (totalScore / maxScore * 100).toInt();
        if (percentage >= passingScore) {
          return 'Сдан';
        } else {
          return 'Не сдан';
        }
      }
      return 'Не сдан';
    }
    
    if (passingScore > 0) {
      if (maxScore > 0) {
        final percentage = (totalScore / maxScore * 100).toInt();
        return percentage >= passingScore ? 'Сдан' : 'Не сдан';
      }
      return 'Не сдан';
    }
    
    if (totalScore > 0 && maxScore > 0) {
      return 'Оценен по баллам';
    }
    
    return 'Не оценен';
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Сдан':
      case 'Зачтено':
        return Colors.green;
      case 'Не сдан':
      case 'Не зачтено':
        return Colors.red;
      case 'Оценен по баллам':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Сдан':
      case 'Зачтено':
        return Icons.check_circle;
      case 'Не сдан':
      case 'Не зачтено':
        return Icons.cancel;
      case 'Оценен по баллам':
        return Icons.score;
      default:
        return Icons.help_outline;
    }
  }
  
  String _getScoringDescription(Map<String, dynamic> testResult) {
    final gradingForm = testResult['grading_form']?.toString().toLowerCase();
    final passingScore = testResult['passing_score'] ?? 0;
    final isPassed = testResult['is_passed'];
    
    if (isPassed != null) {
      return 'Тест оценивается по системе "зачтено/не зачтено"';
    }
    
    if (gradingForm == 'points') {
      if (passingScore > 0) {
        return 'Для сдачи необходимо набрать $passingScore% правильных ответов.';
      } else {
        return 'Тест оценивается по баллам.';
      }
    }
    
    if (passingScore > 0) {
      return 'Для сдачи необходимо набрать $passingScore% правильных ответов.';
    }
    
    return 'Тест оценен по балльной системе.';
  }
  
  bool _isPointsGrading(Map<String, dynamic> testResult) {
    final gradingForm = testResult['grading_form']?.toString().toLowerCase();
    final isPassed = testResult['is_passed'];
    return gradingForm == 'points' || isPassed == null;
  }
  
  Widget _buildAnswerWidget(Map<String, dynamic> question) {
    final answerType = question['answer_type']?.toString().toLowerCase() ?? '';
    final userAnswer = question['user_answer'] ?? {};
    
    if (answerType.contains('текст') || userAnswer['type'] == 'text') {
      return _buildTextAnswer(question);
    } else if (answerType.contains('сопоставление') || userAnswer['type'] == 'matching') {
      return _buildMatchingAnswer(question);
    } else if (answerType.contains('один ответ') || answerType.contains('выбор') || userAnswer['type'] == 'choice') {
      return _buildChoiceAnswer(question);
    }
    
    return _buildTextAnswer(question);
  }
  
  Widget _buildTextAnswer(Map<String, dynamic> question) {
    final userAnswer = question['user_answer'] ?? {};
    final isCorrect = question['is_correct'] == true;
    
    String answerText = 'Нет ответа';
    if (userAnswer['answer_text'] != null) {
      answerText = userAnswer['answer_text'].toString();
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Текстовый ответ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ваш ответ:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Text(
                answerText,
                style: TextStyle(
                  fontSize: 16,
                  color: isCorrect ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChoiceAnswer(Map<String, dynamic> question) {
    final userAnswer = question['user_answer'] ?? {};
    final isCorrect = question['is_correct'] == true;
    
    List<dynamic> choices = [];
    if (userAnswer['choices'] != null) {
      choices = List<Map<String, dynamic>>.from(userAnswer['choices']);
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Вопрос с выбором',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ваши ответы:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            if (choices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Нет выбранных ответов',
                  style: TextStyle(color: isCorrect ? Colors.green : Colors.red),
                ),
              )
            else
              ...choices.map<Widget>((choice) {
                final isSelected = choice['is_selected'] == true;
                final isUserCorrect = choice['is_user_correct'] == true;
                final isCorrectChoice = choice['is_correct'] == true;
                final optionText = choice['option_text']?.toString() ?? 'Вариант ответа';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (isUserCorrect 
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2))
                        : (isCorrect ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? (isUserCorrect ? Colors.green : Colors.red)
                          : (isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected 
                            ? (isUserCorrect ? Icons.check_circle : Icons.cancel)
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? (isUserCorrect ? Colors.green : Colors.red)
                            : (isCorrect ? Colors.green : Colors.red),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              optionText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? (isUserCorrect ? Colors.green : Colors.red)
                                    : (isCorrect ? Colors.green[700] : Colors.red[700]),
                              ),
                            ),
                            if (isCorrectChoice && !isSelected)
                              Text(
                                '(Правильный ответ)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCorrect ? Colors.green : Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMatchingAnswer(Map<String, dynamic> question) {
    final userAnswer = question['user_answer'] ?? {};
    final isCorrect = question['is_correct'] == true;
    
    List<dynamic> pairs = [];
    if (userAnswer['pairs'] != null) {
      pairs = List<Map<String, dynamic>>.from(userAnswer['pairs']);
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Сопоставление',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ваши сопоставления:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            if (pairs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Нет сопоставлений',
                  style: TextStyle(color: isCorrect ? Colors.green : Colors.red),
                ),
              )
            else
              ...pairs.map<Widget>((pair) {
                final isPairCorrect = pair['is_correct'] == true;
                final leftText = pair['left_text']?.toString() ?? 'Левая часть';
                final userSelected = pair['user_selected_right_text']?.toString() ?? 'Не выбрано';
                final correctRight = pair['correct_right_text']?.toString();
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPairCorrect 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPairCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPairCorrect ? Icons.check : Icons.close,
                            color: isPairCorrect ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              leftText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isPairCorrect ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Вы выбрали: $userSelected',
                              style: TextStyle(
                                fontSize: 14,
                                color: isPairCorrect ? Colors.green : Colors.red,
                              ),
                            ),
                            if (correctRight != null && correctRight != userSelected)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Правильно: $correctRight',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isPairCorrect ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(dynamic date) {
    if (date == null) return 'Не указана';
    if (date is String) {
      try {
        final dateTime = DateTime.parse(date);
        return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
      } catch (e) {
        return date;
      }
    }
    return 'Не указана';
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = themeManager.currentTheme;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: const Text(
          'Результат теста',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text('Загрузка деталей...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Ошибка загрузки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                      ),
                      ElevatedButton(onPressed: _loadResultDetails, child: const Text('Повторить попытку')),
                    ],
                  ),
                )
              : _resultData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Данные не найдены', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMainInfoCard(theme),
                          const SizedBox(height: 16),
                          const Text(
                            'Ответы на вопросы:',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ..._buildQuestionsList(),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _goBack,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Вернуться назад'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
  
  List<Widget> _buildQuestionsList() {
    final questions = _resultData!['questions'] as List? ?? [];
    
    return questions.asMap().entries.map<Widget>((entry) {
      final index = entry.key;
      final question = entry.value;
      final isCorrect = question['is_correct'] == true;
      final userScore = question['user_score'] ?? 0;
      final maxScore = question['max_score'] ?? 1;
      final questionText = question['question_text']?.toString() ?? 'Вопрос';
      
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      questionText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isCorrect ? 'Правильно' : 'Неправильно',
                    style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isCorrect ? Colors.green : Colors.red, width: 1),
                    ),
                    child: Text(
                      '$userScore/$maxScore баллов',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              _buildAnswerWidget(question),
            ],
          ),
        ),
      );
    }).toList();
  }
  
Widget _buildMainInfoCard(ThemeData theme) {
  final testResult = _resultData!['test_result'] ?? {};
  final totalScore = testResult['total_score'] ?? 0;
  final maxScore = testResult['max_score'] ?? 1;
  final passingScore = testResult['passing_score'] ?? 0;
  final percentage = maxScore > 0 ? (totalScore / maxScore * 100).toInt() : 0;
  final isPassedByScore = percentage >= passingScore;
  final isPointsSystem = _isPointsGrading(testResult);
  final status = _getTestStatus(testResult);
  
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            testResult['test_name']?.toString() ?? 'Тест',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 24),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPointsSystem ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isPointsSystem ? Colors.blue : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getScoringDescription(testResult),
                    style: TextStyle(
                      fontSize: 14,
                      color: isPointsSystem ? Colors.blue : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Баллы', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        Text(
                          '$totalScore/$maxScore',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isPointsSystem ? Colors.blue : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Процент', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isPointsSystem ? Colors.blue : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Попытка', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${testResult['attempt_number'] ?? 1}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Время', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${testResult['time_spent'] ?? 0} сек',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Дата', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          _formatDate(testResult['completion_date']),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (isPointsSystem && passingScore > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPassedByScore ? Icons.check_circle : Icons.cancel,
                        color: isPassedByScore ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Проходной балл: $passingScore%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isPassedByScore ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ваш результат: $percentage%',
                            style: TextStyle(
                              fontSize: 12,
                              color: isPassedByScore ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
}