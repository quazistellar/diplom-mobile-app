import 'package:flutter/material.dart';

class Assignment {
  final int id;
  final String name;
  final String? description;
  final DateTime? deadline;
  final int? maxScore;
  final int? passingScore;
  final String gradingType;
  final bool isOverdue;
  final bool canSubmit;
  final AssignmentUserStatus? userStatus;
  final AssignmentFeedback? feedback;
  final Map<String, dynamic> rawData;

  Assignment({
    required this.id,
    required this.name,
    this.description,
    this.deadline,
    this.maxScore,
    this.passingScore,
    required this.gradingType,
    required this.isOverdue,
    required this.canSubmit,
    this.userStatus,
    this.feedback,
    required this.rawData,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] ?? 0,
      name: json['practical_assignment_name']?.toString() ?? 'Без названия',
      description: json['practical_assignment_description']?.toString(),
      deadline: _parseDate(json['assignment_deadline']),
      maxScore: json['max_score'],
      passingScore: json['passing_score'],
      gradingType: json['grading_type']?.toString() ?? 'points',
      isOverdue: json['is_overdue'] == true,
      canSubmit: json['can_submit'] == true,
      userStatus: json['user_status'] != null 
          ? AssignmentUserStatus.fromJson(json['user_status'])
          : null,
      feedback: json['feedback'] != null
          ? AssignmentFeedback.fromJson(json['feedback'])
          : null,
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

  bool isCompleted() {
    if (userStatus?.submissionStatus == 'завершено') {
      return true;
    }

    if (feedback != null) {
      return AssignmentGradingChecker.check(
        gradingType: gradingType,
        passingScore: passingScore,
        maxScore: maxScore,
        userScore: feedback!.score ?? userStatus?.score,
        feedbackIsPassed: feedback!.isPassed,
      );
    }

    if (userStatus?.submissionStatus.contains('завершено') == true && userStatus?.score != null) {
      return AssignmentGradingChecker.check(
        gradingType: gradingType,
        passingScore: passingScore,
        maxScore: maxScore,
        userScore: userStatus!.score,
        feedbackIsPassed: null,
      );
    }

    return false;
  }

  String getStatusText() {
    if (isCompleted()) return 'Завершено';
    if (feedback != null) return 'На доработке';
    if (isOverdue) return 'Просрочено';
    if (userStatus?.submissionStatus.contains('отклонено') == true) return 'Отклонено';
    if (userStatus?.submissionStatus.contains('на проверке') == true) return 'На проверке';
    return userStatus?.submissionStatus.isNotEmpty == true ? userStatus!.submissionStatus : 'Не сдано';
  }

  Color getStatusColor() {
    if (isCompleted()) return Colors.green;
    if (feedback != null) return Colors.amber;
    if (isOverdue || userStatus?.submissionStatus.contains('отклонено') == true) return Colors.red;
    if (userStatus?.submissionStatus.contains('на проверке') == true) return Colors.orange;
    return Colors.grey;
  }
}

class AssignmentUserStatus {
  final String submissionStatus;
  final int? score;
  final int? attemptNumber;
  final DateTime? submissionDate;

  AssignmentUserStatus({
    required this.submissionStatus,
    this.score,
    this.attemptNumber,
    this.submissionDate,
  });

  factory AssignmentUserStatus.fromJson(Map<String, dynamic> json) {
    return AssignmentUserStatus(
      submissionStatus: json['submission_status']?.toString().toLowerCase() ?? '',
      score: json['score'],
      attemptNumber: json['attempt_number'],
      submissionDate: _parseDate(json['submission_date']),
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

class AssignmentFeedback {
  final int? score;
  final bool? isPassed;
  final String? feedbackText;
  final String? givenByName;
  final DateTime? givenAt;

  AssignmentFeedback({
    this.score,
    this.isPassed,
    this.feedbackText,
    this.givenByName,
    this.givenAt,
  });

  factory AssignmentFeedback.fromJson(Map<String, dynamic> json) {
    return AssignmentFeedback(
      score: json['score'],
      isPassed: json['is_passed'],
      feedbackText: json['feedback_text']?.toString(),
      givenByName: json['given_by']?['name']?.toString(),
      givenAt: _parseDate(json['given_at']),
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

class AssignmentGradingChecker {
  static bool check({
    required String gradingType,
    required dynamic passingScore,
    required dynamic maxScore,
    required dynamic userScore,
    required dynamic feedbackIsPassed,
  }) {
    if (gradingType == 'points') {
      return _checkPointsGrading(passingScore, maxScore, userScore);
    } else if (gradingType == 'pass_fail') {
      return _checkPassFailGrading(feedbackIsPassed, userScore, maxScore);
    }
    return false;
  }

  static bool _checkPointsGrading(dynamic passingScore, dynamic maxScore, dynamic userScore) {
    if (userScore == null || maxScore == null) return false;

    double numericScore = _toDouble(userScore);
    double numericMaxScore = _toDouble(maxScore);

    if (numericMaxScore <= 0) return false;

    if (passingScore != null) {
      double numericPassingScore = _toDouble(passingScore);
      return numericScore >= numericPassingScore;
    } else {
      double percentage = (numericScore / numericMaxScore) * 100;
      return percentage >= 50;
    }
  }

  static bool _checkPassFailGrading(dynamic feedbackIsPassed, dynamic userScore, dynamic maxScore) {
    if (feedbackIsPassed != null) {
      return feedbackIsPassed == true;
    }

    if (userScore != null && maxScore != null) {
      double numericScore = _toDouble(userScore);
      double numericMaxScore = _toDouble(maxScore);
      if (numericMaxScore <= 0) return false;
      double percentage = (numericScore / numericMaxScore) * 100;
      return percentage >= 50;
    }

    return false;
  }

  static double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0;
  }
}