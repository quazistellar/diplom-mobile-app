import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/theme_provider.dart';
import '../models/test.dart';
import '../utils/snackbar_helper.dart';
import 'test_results_screen.dart';

/// данный класс отображает экран прохождения теста
class TestScreen extends StatefulWidget {
  final int courseId;
  final int testId;
  
  const TestScreen({
    Key? key,
    required this.courseId,
    required this.testId,
  }) : super(key: key);
  
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  Map<String, dynamic>? _testData;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _answers = [];
  int _currentQuestion = 0;
  int _timeSpent = 0;
  bool _isSubmitting = false;
  bool _testSubmitted = false;
  Map<String, dynamic>? _testResult;
  Test? _test;

  @override
  void initState() {
    super.initState();
    print('TestScreen init: courseId=${widget.courseId}, testId=${widget.testId}');
    _loadTest();
    _startTimer();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// данный метод загружает данные теста
  Future<void> _loadTest() async {
    print('Загрузка теста...');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      print('Запрашиваем тест у провайдера...');
      
      final data = await progressProvider.getTest(widget.courseId, widget.testId);
      
      print('Получены данные теста. Ключи: ${data.keys.toList()}');
      
      if (data['test'] != null) {
        _test = Test.fromJson(data['test']);
      }
      
      if (data['questions'] != null && (data['questions'] as List).isNotEmpty) {
        final questions = data['questions'] as List;
        for (int i = 0; i < questions.length; i++) {
          final question = questions[i];
          print('\n=== ВОПРОС ${i + 1} ===');
          print('ID: ${question['id']}');
          print('Текст: ${question['question_text']}');
          print('Тип ответа: ${question['answer_type']}');
          print('Баллы: ${question['question_score']}');
        }
      }
      
      setState(() {
        _testData = data;
        _isLoading = false;
        
        final questions = data['questions'] ?? [];
        print('Всего вопросов: ${questions.length}');
        
        for (var question in questions) {
          String answerType = 'текст'; 
          
          if (question['answer_type'] is String) {
            answerType = question['answer_type'];
          } else if (question['answer_type'] is Map) {
            answerType = question['answer_type']['answer_type_name'] ?? 'текст';
          }
          
          final normalizedType = _normalizeAnswerType(answerType);
          
          _answers.add({
            'question_id': question['id'],
            'answer_type': normalizedType,
            'answer_text': '',
            'selected_choice_ids': [],
            'matching_data': [],
          });
        }
        
        print('Инициализировано ответов: ${_answers.length}');
      });
    } catch (e) {
      print('Ошибка загрузки теста: $e');
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// данный метод нормализует тип ответа
  String _normalizeAnswerType(String answerType) {
    if (answerType.isEmpty) return 'текст';
    
    final lowerType = answerType.toLowerCase();

    if (lowerType.contains('один') || 
        lowerType.contains('single') || 
        lowerType.contains('radio')) {
      return 'один ответ';
    } else if (lowerType.contains('несколько') || 
               lowerType.contains('multiple') || 
               lowerType.contains('checkbox')) {
      return 'несколько ответов';
    } else if (lowerType.contains('сопоставление') || 
               lowerType.contains('matching')) {
      return 'сопоставление';
    }
    
    return 'текст';
  }

  /// данный метод запускает таймер
  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_testSubmitted) {
        setState(() => _timeSpent++);
        _startTimer();
      }
    });
  }

  /// данный метод отправляет тест на проверку
  Future<void> _submitTest() async {
    if (_isSubmitting || _testSubmitted) return;
    
    setState(() => _isSubmitting = true);

    try {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      
      final formattedAnswers = _answers.map((answer) {
        final result = <String, dynamic>{
          'question_id': answer['question_id'],
        };
        
        final type = answer['answer_type'];
        
        if (type == 'текст') {
          result['answer_type'] = 'text';
          result['answer_text'] = answer['answer_text'] ?? '';
        } else if (type == 'один ответ' || type == 'несколько ответов') {
          result['answer_type'] = 'choice';
          result['selected_choice_ids'] = answer['selected_choice_ids'] ?? [];
        } else if (type == 'сопоставление') {
          result['answer_type'] = 'matching';
          result['matching_data'] = answer['matching_data'] ?? [];
        }
        
        return result;
      }).toList();
      
      print('Отправка теста с ${formattedAnswers.length} ответами...');
      
      final result = await progressProvider.submitTest(
        widget.courseId,
        widget.testId,
        formattedAnswers,
        _timeSpent,
      );
      
      setState(() {
        _testResult = result;
        _testSubmitted = true;
      });
      
      SnackBarHelper.showSuccess(context, 'Тест успешно отправлен!');
      
    } catch (e) {
      print('Ошибка отправки теста: $e');
      SnackBarHelper.showError(context, 'Ошибка отправки: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// данный метод возвращает на предыдущий экран
  void _goBack() {
    Navigator.pop(context);
  }

  /// данный метод переходит к следующему вопросу
  void _nextQuestion() {
    if (_currentQuestion < ((_testData?['questions'] ?? []).length - 1)) {
      setState(() => _currentQuestion++);
    }
  }

  /// данный метод возвращается к предыдущему вопросу
  void _previousQuestion() {
    if (_currentQuestion > 0) {
      setState(() => _currentQuestion--);
    }
  }

  /// данный метод форматирует дату
  String _formatDate(dynamic date) {
    if (date == null) return 'Не указана';
    
    if (date is String) {
      try {
        final dateTime = DateTime.parse(date);
        return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return date;
      }
    }

    if (date is int) {
      try {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(date * 1000);
        return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return date.toString();
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
        title: Text(
          _testSubmitted ? 'Результат теста' : 'Тест',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: _testSubmitted ? null : [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_timeSpent ~/ 60}:${(_timeSpent % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _testSubmitted ? _buildResultScreen(theme) : _buildTestScreen(theme),
      bottomNavigationBar: _testSubmitted ? null : _buildBottomBar(theme),
    );
  }

  /// данный метод создает экран прохождения теста
  Widget _buildTestScreen(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Загрузка теста...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Ошибка загрузки теста', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            ),
            ElevatedButton(onPressed: _loadTest, child: const Text('Повторить попытку')),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _goBack, child: const Text('Вернуться назад')),
          ],
        ),
      );
    }

    if (_testData == null || _answers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Данные теста не найдены', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadTest, child: const Text('Загрузить тест')),
          ],
        ),
      );
    }

    final questions = _testData!['questions'] ?? [];
    if (questions.isEmpty || _currentQuestion >= questions.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.question_mark, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text('Вопросы не найдены', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    final currentQuestion = questions[_currentQuestion];
    final currentAnswer = _answers[_currentQuestion];
    final test = _testData!['test'] ?? {};
    final maxAttempts = test['max_attempts'];
    final currentAttempt = _testData!['current_attempt'] ?? 1;

    return Column(
      children: [
        Card(
          elevation: 2,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        test['test_name'] ?? 'Тест',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (maxAttempts != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Попытка $currentAttempt/$maxAttempts',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (test['test_description'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      test['test_description']!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (_currentQuestion + 1) / questions.length,
                  backgroundColor: theme.colorScheme.surface,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentQuestion + 1}/${questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Вопрос ${_currentQuestion + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  currentQuestion['question_text']?.toString() ?? 'Без текста',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                
                if (currentQuestion.containsKey('question_score'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Баллов за вопрос: ${currentQuestion['question_score']}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                _buildAnswerWidget(currentQuestion, currentAnswer, theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// данный метод создает виджет ответа на вопрос
  Widget _buildAnswerWidget(
    Map<String, dynamic> question, 
    Map<String, dynamic> currentAnswer,
    ThemeData theme,
  ) {
    final answerType = currentAnswer['answer_type'];
    List<dynamic> options = [];
    List<dynamic> pairs = [];
    
    if (question.containsKey('choiceoption_set')) {
      final rawOptions = question['choiceoption_set'];
      if (rawOptions is List) options = rawOptions;
    }
    
    if (question.containsKey('matchingpair_set')) {
      final rawPairs = question['matchingpair_set'];
      if (rawPairs is List) pairs = rawPairs;
    }
    
    if (answerType == 'один ответ') {
      return _buildSingleChoice(options, currentAnswer, theme);
    } else if (answerType == 'несколько ответов') {
      return _buildMultipleChoice(options, currentAnswer, theme);
    } else if (answerType == 'сопоставление') {
      return _buildMatchingWithDropdown(pairs, currentAnswer, theme);
    } else {
      return _buildTextAnswer(currentAnswer, theme);
    }
  }

  /// данный метод создает виджет сопоставления с выпадающими списками
  Widget _buildMatchingWithDropdown(
    List<dynamic> pairs,
    Map<String, dynamic> currentAnswer,
    ThemeData theme,
  ) {
    final matchingData = List<Map<String, dynamic>>.from(currentAnswer['matching_data'] ?? []);
    
    if (pairs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сопоставьте элементы:',
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Пары для сопоставления не найдены',
            style: TextStyle(color: Colors.orange),
          ),
        ],
      );
    }
    
    final effectiveRightOptions = <String>{};
    for (var pair in pairs) {
      if (pair['right_text'] != null && pair['right_text'].toString().isNotEmpty) {
        effectiveRightOptions.add(pair['right_text'].toString());
      }
    }
    
    final rightOptionsList = effectiveRightOptions.toList()..sort();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите из выпадающих списков верные сопоставления:',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
        ),
        const SizedBox(height: 16),
        ...pairs.asMap().entries.map<Widget>((entry) {
          final index = entry.key;
          final pair = entry.value;
          final leftText = pair['left_text']?.toString() ?? 'Левая часть';
          final pairId = pair['id'];
          
          String? currentValue;
          for (var match in matchingData) {
            if (match['pair_id'] == pairId) {
              currentValue = match['selected_right_text'];
              break;
            }
          }
          
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
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          leftText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: currentValue,
                        hint: const Text('Выберите соответствие...', style: TextStyle(color: Colors.grey)),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Не выбрано', style: TextStyle(color: Colors.grey)),
                          ),
                          ...rightOptionsList.map<DropdownMenuItem<String>>((option) {
                            return DropdownMenuItem<String>(
                              value: option,
                              child: Text(option, style: const TextStyle(fontSize: 16)),
                            );
                          }).toList(),
                        ],
                        onChanged: (String? newValue) {
                          final existingIndex = matchingData.indexWhere((m) => m['pair_id'] == pairId);
                          
                          if (newValue != null && newValue.isNotEmpty) {
                            if (existingIndex >= 0) {
                              matchingData[existingIndex]['selected_right_text'] = newValue;
                            } else {
                              matchingData.add({'pair_id': pairId, 'selected_right_text': newValue});
                            }
                          } else if (existingIndex >= 0) {
                            matchingData.removeAt(existingIndex);
                          }
                          
                          setState(() => currentAnswer['matching_data'] = matchingData);
                        },
                      ),
                    ),
                  ),
                  
                  if (currentValue != null && currentValue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Выбрано: $currentValue',
                        style: const TextStyle(color: Colors.green, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  /// данный метод создает виджет выбора одного ответа
  Widget _buildSingleChoice(
    List<dynamic> options,
    Map<String, dynamic> currentAnswer,
    ThemeData theme,
  ) {
    final selectedId = (currentAnswer['selected_choice_ids'] as List).isNotEmpty
        ? (currentAnswer['selected_choice_ids'] as List)[0]
        : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите один правильный ответ:',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
        ),
        const SizedBox(height: 16),
        ...options.map<Widget>((option) {
          final optionId = option['id'];
          final optionText = option['option_text']?.toString() ?? 'Вариант ответа';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: RadioListTile(
              title: Text(optionText, style: const TextStyle(fontSize: 16)),
              value: optionId,
              groupValue: selectedId,
              onChanged: (value) => setState(() => currentAnswer['selected_choice_ids'] = [value]),
            ),
          );
        }).toList(),
      ],
    );
  }

  /// данный метод создает виджет выбора нескольких ответов
  Widget _buildMultipleChoice(
    List<dynamic> options,
    Map<String, dynamic> currentAnswer,
    ThemeData theme,
  ) {
    final selectedIds = List<int>.from(currentAnswer['selected_choice_ids'] ?? []);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите все правильные ответы:',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
        ),
        const SizedBox(height: 16),
        ...options.map<Widget>((option) {
          final optionId = option['id'];
          final optionText = option['option_text']?.toString() ?? 'Вариант ответа';
          final isSelected = selectedIds.contains(optionId);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: isSelected ? theme.primaryColor.withOpacity(0.1) : null,
            child: CheckboxListTile(
              title: Text(optionText, style: const TextStyle(fontSize: 16)),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    selectedIds.add(optionId);
                  } else {
                    selectedIds.remove(optionId);
                  }
                  currentAnswer['selected_choice_ids'] = selectedIds;
                });
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  /// данный метод создает виджет текстового ответа
  Widget _buildTextAnswer(
    Map<String, dynamic> currentAnswer,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Введите ваш ответ:',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
        ),
        const SizedBox(height: 12),
        TextField(
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Введите текст ответа...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (value) => setState(() => currentAnswer['answer_text'] = value),
        ),
      ],
    );
  }

  /// данный метод создает экран с результатом теста
  Widget _buildResultScreen(ThemeData theme) {
    final test = _testData?['test'] ?? {};
    final score = _testResult?['total_score'] ?? 0;
    final maxScore = _testResult?['max_score'] ?? 1;
    final gradingForm = test['grading_form'] ?? 'points';
    final passingScore = test['passing_score'];
    final intScore = score is int ? score : score.round();
    final intMaxScore = maxScore is int ? maxScore : maxScore.round();
    bool isPassed = false;
    
    if (gradingForm == 'pass_fail') {
      isPassed = _testResult?['is_passed'] == true;
    } else {
      if (passingScore != null) {
        final intPassingScore = passingScore is int ? passingScore : passingScore.round();
        isPassed = intScore >= intPassingScore;
      } else {
        isPassed = intScore >= (intMaxScore / 2);
      }
    }
    
    final testResultId = _testResult?['test_result_id'];
    final percentage = intMaxScore > 0 ? (intScore / intMaxScore * 100).round() : 0;
    final attemptNumber = _testResult?['attempt_number'] ?? 1;
    final maxAttempts = test['max_attempts'];
    final passedFinalTest = _testResult?['passed_final_test'] == true;
    final completionDate = _testResult?['completion_date'];
    final formattedDate = _formatDate(completionDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          
          Icon(
            isPassed ? Icons.check_circle_outline : Icons.error_outline,
            size: 100,
            color: isPassed ? Colors.green : Colors.orange,
          ),
          
          const SizedBox(height: 24),
          
          Text(
            isPassed ? 'Тест пройден!' : 'Тест не пройден',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isPassed ? Colors.green : Colors.orange,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            test['test_name'] ?? 'Тест',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Форма оценки: ${gradingForm == 'points' ? 'По баллам' : 'Зачёт/незачёт'}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          
          if (passingScore != null && gradingForm == 'points')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Проходной балл: ${passingScore is int ? passingScore : passingScore.round()}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          
          if (passedFinalTest)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Финальный тест пройден!',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 32),
          
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 10,
                  backgroundColor: theme.colorScheme.surface,
                  color: isPassed ? Colors.green : Colors.orange,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$percentage%',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$intScore/$intMaxScore',  
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Попытка:', style: TextStyle(color: Colors.grey)),
                      Text(
                        '$attemptNumber${maxAttempts != null ? '/$maxAttempts' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Время:', style: TextStyle(color: Colors.grey)),
                      Text(
                        '${_timeSpent ~/ 60}:${(_timeSpent % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Статус:', style: TextStyle(color: Colors.grey)),
                      Text(
                        isPassed ? 'Зачтено' : 'Не зачтено',
                        style: TextStyle(
                          color: isPassed ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Получено баллов:', style: TextStyle(color: Colors.grey)),
                      Text(
                        '$intScore',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (formattedDate != 'Не указана')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Дата:', style: TextStyle(color: Colors.grey)),
                          Text(
                            formattedDate,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          if (testResultId != null)
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TestResultScreen(
                          testResultId: testResultId,
                          courseId: widget.courseId,
                          testId: widget.testId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Посмотреть детали ответов'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    minimumSize: const Size(250, 50),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
                final attempts = await progressProvider.getTestAttempts(widget.courseId, widget.testId);
                _showTestAttemptsDialog(attempts, test);
              } catch (e) {
                print('Ошибка загрузки попыток: $e');
                SnackBarHelper.showError(context, 'Ошибка загрузки попыток');
              }
            },
            icon: const Icon(Icons.history),
            label: const Text('История попыток'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(250, 50),
            ),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: _goBack,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(250, 50),
            ),
            child: const Text('Вернуться к курсу'),
          ),
        ],
      ),
    );
  }

  /// данный метод показывает диалог с историей попыток
  void _showTestAttemptsDialog(Map<String, dynamic> attemptsData, Map<String, dynamic> test) {
    final attempts = attemptsData['attempts'] as List? ?? [];
    final gradingForm = test['grading_form'] ?? 'points';
    final passingScore = test['passing_score'];
    final maxScore = test['max_score'] ?? 100;
    
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
                attemptsData['test']['name'] ?? 'Тест',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (gradingForm != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Форма оценки: ${gradingForm == 'points' ? 'По баллам' : 'Зачёт/незачёт'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              if (passingScore != null && gradingForm == 'points')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Проходной балл: $passingScore',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
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
                  final attemptScore = attempt['total_score'] ?? 0;
                  bool isPassed = false;
                  
                  if (gradingForm == 'pass_fail') {
                    isPassed = attempt['is_passed'] == true;
                  } else {
                    if (passingScore != null) {
                      isPassed = attemptScore >= passingScore;
                    } else {
                      isPassed = attemptScore >= (maxScore / 2);
                    }
                  }
                  
                  final percentage = maxScore > 0 ? (attemptScore / maxScore * 100).round() : 0;
                  
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
                            '${attempt['correct_answers'] ?? 0}/${attempt['total_questions'] ?? 0} правильных',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Баллы: $attemptScore',
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
                                      testId: widget.testId,
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
                                    testId: widget.testId,
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

  /// данный метод создает нижнюю панель навигации
  Widget _buildBottomBar(ThemeData theme) {
    final questions = _testData?['questions'] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(
          top: BorderSide(color: theme.dividerTheme.color ?? Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (_currentQuestion > 0)
            OutlinedButton(onPressed: _previousQuestion, child: const Text('Назад')),
          
          const Spacer(),
          
          if (_currentQuestion < questions.length - 1)
            ElevatedButton(onPressed: _nextQuestion, child: const Text('Далее')),
          
          if (_currentQuestion == questions.length - 1 && questions.isNotEmpty)
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Завершить тест'),
            ),
        ],
      ),
    );
  }
}