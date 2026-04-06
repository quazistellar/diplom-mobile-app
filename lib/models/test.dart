import 'package:flutter/material.dart';

/// данный класс представляет модель теста
class Test {
  final int id;
  final String name;
  final String? description;
  final bool isFinal;
  final int? maxAttempts;
  final bool isActive;
  final String gradingForm;
  final int? passingScore;
  final int? maxScore;
  final TestUserResult? userResult;
  final Map<String, dynamic> rawData;

  Test({
    required this.id,
    required this.name,
    this.description,
    required this.isFinal,
    this.maxAttempts,
    required this.isActive,
    required this.gradingForm,
    this.passingScore,
    this.maxScore,
    this.userResult,
    required this.rawData,
  });

  /// данная функция создает объект теста из JSON
  factory Test.fromJson(Map<String, dynamic> json) {
    return Test(
      id: json['id'] ?? 0,
      name: json['test_name']?.toString() ?? 'Без названия',
      description: json['test_description']?.toString(),
      isFinal: json['is_final'] == true,
      maxAttempts: json['max_attempts'],
      isActive: json['is_active'] ?? true,
      gradingForm: json['grading_form']?.toString() ?? 'points',
      passingScore: json['passing_score'],
      maxScore: json['max_score'] ?? 100,
      userResult: json['user_result'] != null
          ? TestUserResult.fromJson(json['user_result'])
          : null,
      rawData: json,
    );
  }

  /// данная функция возвращает статус прохождения теста
  bool get isPassed {
    if (userResult == null) return false;
    
    if (gradingForm == 'pass_fail') {
      return userResult!.isPassed == true;
    } else {
      if (passingScore != null) {
        if (passingScore! > 1) {
          final percentage = (userResult!.finalScore / (maxScore ?? 1)) * 100;
          return percentage >= passingScore!;
        } else {
          return userResult!.finalScore >= (passingScore! * (maxScore ?? 1));
        }
      }
      final percentage = (userResult!.finalScore / (maxScore ?? 1)) * 100;
      return percentage >= 50;
    }
  }

  /// данная функция возвращает текстовое описание статуса
  String getStatusText() {
    if (userResult == null) return 'Не начат';
    if (isPassed) return 'Сдан';
    return 'Не сдан';
  }

  /// данная функция возвращает цвет статуса
  Color getStatusColor() {
    if (userResult == null) return Colors.grey;
    if (isPassed) return Colors.green;
    return Colors.red;
  }

  /// данная функция возвращает количество использованных попыток
  int get attemptsUsed => userResult?.attemptNumber ?? 0;
  
  /// данная функция возвращает количество оставшихся попыток
  int get attemptsLeft => maxAttempts != null ? maxAttempts! - attemptsUsed : 0;
  
  /// данная функция проверяет, доступна ли попытка
  bool get canAttempt => maxAttempts == null || attemptsUsed < maxAttempts!;
}

/// данный класс представляет результат теста пользователя
class TestUserResult {
  final int? id;
  final int finalScore;
  final bool? isPassed;
  final int attemptNumber;
  final DateTime? completionDate;
  final int? timeSpent;
  final Map<String, dynamic> rawData;

  TestUserResult({
    this.id,
    required this.finalScore,
    this.isPassed,
    required this.attemptNumber,
    this.completionDate,
    this.timeSpent,
    required this.rawData,
  });

  /// данная функция создает объект результата теста из JSON
  factory TestUserResult.fromJson(Map<String, dynamic> json) {
    return TestUserResult(
      id: json['id'],
      finalScore: json['final_score'] ?? 0,
      isPassed: json['is_passed'],
      attemptNumber: json['attempt_number'] ?? 0,
      completionDate: _parseDate(json['completion_date']),
      timeSpent: json['time_spent'],
      rawData: json,
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    try {
      return DateTime.parse(date.toString());
    } catch (_) {
      return null;
    }
  }
}

/// данный класс представляет вопрос теста
class TestQuestion {
  final int id;
  final String questionText;
  final String answerType;
  final int questionScore;
  final List<TestChoiceOption>? choiceOptions;
  final List<TestMatchingPair>? matchingPairs;
  final Map<String, dynamic> rawData;

  TestQuestion({
    required this.id,
    required this.questionText,
    required this.answerType,
    required this.questionScore,
    this.choiceOptions,
    this.matchingPairs,
    required this.rawData,
  });

  /// данная функция создает объект вопроса теста из JSON
  factory TestQuestion.fromJson(Map<String, dynamic> json) {
    String answerType = 'текст';
    if (json['answer_type'] is String) {
      answerType = json['answer_type'];
    } else if (json['answer_type'] is Map) {
      answerType = json['answer_type']['answer_type_name'] ?? 'текст';
    }


    answerType = _normalizeAnswerType(answerType);
    List<TestChoiceOption>? choiceOptions;
    if (json['choiceoption_set'] != null) {
      choiceOptions = (json['choiceoption_set'] as List)
          .map((opt) => TestChoiceOption.fromJson(opt))
          .toList();
    }

    List<TestMatchingPair>? matchingPairs;
    if (json['matchingpair_set'] != null) {
      matchingPairs = (json['matchingpair_set'] as List)
          .map((pair) => TestMatchingPair.fromJson(pair))
          .toList();
    }

    return TestQuestion(
      id: json['id'] ?? 0,
      questionText: json['question_text']?.toString() ?? 'Без текста',
      answerType: answerType,
      questionScore: json['question_score'] ?? 0,
      choiceOptions: choiceOptions,
      matchingPairs: matchingPairs,
      rawData: json,
    );
  }

  static String _normalizeAnswerType(String answerType) {
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

  /// данная функция проверяет, является ли вопрос с одним ответом
  bool get isSingleChoice => answerType == 'один ответ';
  
  /// данная функция проверяет, является ли вопрос с несколькими ответами
  bool get isMultipleChoice => answerType == 'несколько ответов';
  
  /// данная функция проверяет, является ли вопрос сопоставлением
  bool get isMatching => answerType == 'сопоставление';
  
  /// данная функция проверяет, является ли вопрос текстовым
  bool get isText => answerType == 'текст';
}

/// данный класс представляет вариант ответа в тесте
class TestChoiceOption {
  final int id;
  final String optionText;
  final bool? isCorrect;

  TestChoiceOption({
    required this.id,
    required this.optionText,
    this.isCorrect,
  });

  /// данная функция создает объект варианта ответа из JSON
  factory TestChoiceOption.fromJson(Map<String, dynamic> json) {
    return TestChoiceOption(
      id: json['id'] ?? 0,
      optionText: json['option_text']?.toString() ?? 'Вариант ответа',
      isCorrect: json['is_correct'],
    );
  }
}

/// данный класс представляет пару для сопоставления
class TestMatchingPair {
  final int id;
  final String leftText;
  final String? rightText;

  TestMatchingPair({
    required this.id,
    required this.leftText,
    this.rightText,
  });

  /// данная функция создает объект пары для сопоставления из JSON
  factory TestMatchingPair.fromJson(Map<String, dynamic> json) {
    return TestMatchingPair(
      id: json['id'] ?? 0,
      leftText: json['left_text']?.toString() ?? 'Левая часть',
      rightText: json['right_text']?.toString(),
    );
  }
}

/// данный класс представляет попытку прохождения теста
class TestAttempt {
  final int id;
  final int attemptNumber;
  final int totalScore;
  final int? maxScore;
  final int correctAnswers;
  final int totalQuestions;
  final int timeSpent;
  final bool? isPassed;
  final DateTime completionDate;
  final double percentage;

  TestAttempt({
    required this.id,
    required this.attemptNumber,
    required this.totalScore,
    this.maxScore,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.timeSpent,
    this.isPassed,
    required this.completionDate,
    required this.percentage,
  });

  /// данная функция создает объект попытки из JSON
  factory TestAttempt.fromJson(Map<String, dynamic> json) {
    final totalScore = json['total_score'] ?? 0;
    final maxScore = json['max_score'] ?? 100;
    
    return TestAttempt(
      id: json['id'] ?? 0,
      attemptNumber: json['attempt_number'] ?? 1,
      totalScore: totalScore,
      maxScore: maxScore,
      correctAnswers: json['correct_answers'] ?? 0,
      totalQuestions: json['total_questions'] ?? 0,
      timeSpent: json['time_spent'] ?? 0,
      isPassed: json['is_passed'],
      completionDate: DateTime.parse(json['completion_date']),
      percentage: json['percentage'] ?? (maxScore > 0 ? (totalScore / maxScore * 100) : 0),
    );
  }

  /// данная функция проверяет, пройдена ли попытка
  bool get isPassedByScore {
    if (isPassed != null) return isPassed!;
    return percentage >= 50;
  }
}

/// данный класс представляет детали результата теста
class TestResultDetail {
  final TestResultInfo testResult;
  final List<TestQuestionResult> questions;

  TestResultDetail({
    required this.testResult,
    required this.questions,
  });

  /// данная функция создает объект деталей результата из JSON
  factory TestResultDetail.fromJson(Map<String, dynamic> json) {
    return TestResultDetail(
      testResult: TestResultInfo.fromJson(json['test_result'] ?? {}),
      questions: (json['questions'] as List? ?? [])
          .map((q) => TestQuestionResult.fromJson(q))
          .toList(),
    );
  }
}

/// данный класс представляет информацию о результате теста
class TestResultInfo {
  final int id;
  final String testName;
  final int totalScore;
  final int maxScore;
  final int? passingScore;
  final String gradingForm;
  final int attemptNumber;
  final int timeSpent;
  final DateTime createdAt;
  final bool? isPassed;

  TestResultInfo({
    required this.id,
    required this.testName,
    required this.totalScore,
    required this.maxScore,
    this.passingScore,
    required this.gradingForm,
    required this.attemptNumber,
    required this.timeSpent,
    required this.createdAt,
    this.isPassed,
  });

  /// данная функция создает объект информации о результате из JSON
  factory TestResultInfo.fromJson(Map<String, dynamic> json) {
    return TestResultInfo(
      id: json['id'] ?? 0,
      testName: json['test_name']?.toString() ?? 'Тест',
      totalScore: json['total_score'] ?? 0,
      maxScore: json['max_score'] ?? 1,
      passingScore: json['passing_score'],
      gradingForm: json['grading_form']?.toString() ?? 'points',
      attemptNumber: json['attempt_number'] ?? 1,
      timeSpent: json['time_spent'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isPassed: json['is_passed'],
    );
  }

  /// данная функция возвращает процент выполнения
  int get percentage => maxScore > 0 ? (totalScore / maxScore * 100).toInt() : 0;
  
  /// данная функция проверяет, пройден ли тест по баллам
  bool get isPassedByScore {
    if (isPassed != null) return isPassed!;
    if (gradingForm == 'pass_fail') return false;
    if (passingScore != null) {
      if (passingScore! > 1) return percentage >= passingScore!;
      return totalScore >= (passingScore! * maxScore);
    }
    return percentage >= 50;
  }
}

/// данный класс представляет результат ответа на вопрос
class TestQuestionResult {
  final int id;
  final String questionText;
  final bool isCorrect;
  final int userScore;
  final int maxScore;
  final String answerType;
  final Map<String, dynamic> userAnswer;
  final List<TestChoiceResult>? choices;
  final List<TestMatchingResult>? pairs;

  TestQuestionResult({
    required this.id,
    required this.questionText,
    required this.isCorrect,
    required this.userScore,
    required this.maxScore,
    required this.answerType,
    required this.userAnswer,
    this.choices,
    this.pairs,
  });

  /// данная функция создает объект результата вопроса из JSON
  factory TestQuestionResult.fromJson(Map<String, dynamic> json) {
    return TestQuestionResult(
      id: json['id'] ?? 0,
      questionText: json['question_text']?.toString() ?? 'Вопрос',
      isCorrect: json['is_correct'] == true,
      userScore: json['user_score'] ?? 0,
      maxScore: json['max_score'] ?? 1,
      answerType: json['answer_type']?.toString() ?? 'текст',
      userAnswer: json['user_answer'] ?? {},
      choices: json['choices'] != null
          ? (json['choices'] as List).map((c) => TestChoiceResult.fromJson(c)).toList()
          : null,
      pairs: json['pairs'] != null
          ? (json['pairs'] as List).map((p) => TestMatchingResult.fromJson(p)).toList()
          : null,
    );
  }
}

/// данный класс представляет результат выбора варианта
class TestChoiceResult {
  final int id;
  final String optionText;
  final bool isSelected;
  final bool isCorrect;
  final bool isUserCorrect;

  TestChoiceResult({
    required this.id,
    required this.optionText,
    required this.isSelected,
    required this.isCorrect,
    required this.isUserCorrect,
  });

  /// данная функция создает объект результата выбора из JSON
  factory TestChoiceResult.fromJson(Map<String, dynamic> json) {
    return TestChoiceResult(
      id: json['id'] ?? 0,
      optionText: json['option_text']?.toString() ?? 'Вариант',
      isSelected: json['is_selected'] == true,
      isCorrect: json['is_correct'] == true,
      isUserCorrect: json['is_user_correct'] == true,
    );
  }
}

/// данный класс представляет результат сопоставления
class TestMatchingResult {
  final int id;
  final String leftText;
  final String? userSelectedRightText;
  final String? correctRightText;
  final bool isCorrect;

  TestMatchingResult({
    required this.id,
    required this.leftText,
    this.userSelectedRightText,
    this.correctRightText,
    required this.isCorrect,
  });

  /// данная функция создает объект результата сопоставления из JSON
  factory TestMatchingResult.fromJson(Map<String, dynamic> json) {
    return TestMatchingResult(
      id: json['id'] ?? 0,
      leftText: json['left_text']?.toString() ?? 'Левая часть',
      userSelectedRightText: json['user_selected_right_text']?.toString(),
      correctRightText: json['correct_right_text']?.toString(),
      isCorrect: json['is_correct'] == true,
    );
  }
}