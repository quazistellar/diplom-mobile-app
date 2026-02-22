import 'package:flutter/material.dart';

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

  String getStatusText() {
    if (userResult == null) return 'Не начат';
    if (isPassed) return 'Сдан';
    return 'Не сдан';
  }

  Color getStatusColor() {
    if (userResult == null) return Colors.grey;
    if (isPassed) return Colors.green;
    return Colors.red;
  }

  int get attemptsUsed => userResult?.attemptNumber ?? 0;
  int get attemptsLeft => maxAttempts != null ? maxAttempts! - attemptsUsed : 0;
  bool get canAttempt => maxAttempts == null || attemptsUsed < maxAttempts!;
}

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

  bool get isSingleChoice => answerType == 'один ответ';
  bool get isMultipleChoice => answerType == 'несколько ответов';
  bool get isMatching => answerType == 'сопоставление';
  bool get isText => answerType == 'текст';
}

class TestChoiceOption {
  final int id;
  final String optionText;
  final bool? isCorrect;

  TestChoiceOption({
    required this.id,
    required this.optionText,
    this.isCorrect,
  });

  factory TestChoiceOption.fromJson(Map<String, dynamic> json) {
    return TestChoiceOption(
      id: json['id'] ?? 0,
      optionText: json['option_text']?.toString() ?? 'Вариант ответа',
      isCorrect: json['is_correct'],
    );
  }
}

class TestMatchingPair {
  final int id;
  final String leftText;
  final String? rightText;

  TestMatchingPair({
    required this.id,
    required this.leftText,
    this.rightText,
  });

  factory TestMatchingPair.fromJson(Map<String, dynamic> json) {
    return TestMatchingPair(
      id: json['id'] ?? 0,
      leftText: json['left_text']?.toString() ?? 'Левая часть',
      rightText: json['right_text']?.toString(),
    );
  }
}

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

  bool get isPassedByScore {
    if (isPassed != null) return isPassed!;
    return percentage >= 50;
  }
}

class TestResultDetail {
  final TestResultInfo testResult;
  final List<TestQuestionResult> questions;

  TestResultDetail({
    required this.testResult,
    required this.questions,
  });

  factory TestResultDetail.fromJson(Map<String, dynamic> json) {
    return TestResultDetail(
      testResult: TestResultInfo.fromJson(json['test_result'] ?? {}),
      questions: (json['questions'] as List? ?? [])
          .map((q) => TestQuestionResult.fromJson(q))
          .toList(),
    );
  }
}

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

  int get percentage => maxScore > 0 ? (totalScore / maxScore * 100).toInt() : 0;
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