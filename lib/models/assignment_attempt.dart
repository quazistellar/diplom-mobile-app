import 'package:flutter/material.dart';
import 'assignment.dart';

class AssignmentAttempt {
  final int id;
  final int attemptNumber;
  final DateTime submissionDate;
  final String? comment;
  final List<AssignmentFile> files;
  final AssignmentFeedback? feedback;
  final AssignmentStatus status;
  final bool isOverdue;
  final String gradingType;
  final int? maxScore;
  final int? passingScore;
  final int? score;
  final bool canEdit;
  final Map<String, dynamic> rawData;

  AssignmentAttempt({
    required this.id,
    required this.attemptNumber,
    required this.submissionDate,
    this.comment,
    required this.files,
    this.feedback,
    required this.status,
    required this.isOverdue,
    required this.gradingType,
    this.maxScore,
    this.passingScore,
    this.score,
    required this.canEdit,
    required this.rawData,
  });

  factory AssignmentAttempt.fromJson(Map<String, dynamic> json) {
    final status = AssignmentStatus.fromJson(json['status'] ?? {});
    
    return AssignmentAttempt(
      id: json['id'] ?? 0,
      attemptNumber: json['attempt_number'] ?? 1,
      submissionDate: _parseDate(json['submission_date']) ?? DateTime.now(),
      comment: json['comment']?.toString(),
      files: (json['files'] as List? ?? [])
          .map((f) => AssignmentFile.fromJson(f))
          .toList(),
      feedback: json['feedback'] != null
          ? AssignmentFeedback.fromJson(json['feedback'])
          : null,
      status: status,
      isOverdue: json['is_overdue'] == true,
      gradingType: json['grading_type']?.toString() ?? 'points',
      maxScore: json['max_score'],
      passingScore: json['passing_score'],
      score: json['score'],
      canEdit: json['can_edit'] == true,
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

  bool get isCompleted {
    if (feedback != null) {
      return AssignmentGradingChecker.check(
        gradingType: gradingType,
        passingScore: passingScore,
        maxScore: maxScore,
        userScore: feedback!.score ?? score,
        feedbackIsPassed: feedback!.isPassed,
      );
    }
    return status.name.toLowerCase() == 'завершено';
  }

  String get displayStatus {
    if (feedback != null) {
      if (isCompleted) return 'Завершено';
      return 'На доработке';
    }
    return status.name;
  }

  Color get statusColor {
    if (isCompleted) return Colors.green;
    if (feedback != null) return Colors.amber;
    if (isOverdue || status.name.toLowerCase().contains('отклонено')) return Colors.red;
    if (status.name.toLowerCase().contains('на проверке')) return Colors.orange;
    return Colors.grey;
  }
}

class AssignmentStatus {
  final String name;
  final String description;
  final String color;
  final bool canEdit;

  AssignmentStatus({
    required this.name,
    required this.description,
    required this.color,
    required this.canEdit,
  });

  factory AssignmentStatus.fromJson(Map<String, dynamic> json) {
    return AssignmentStatus(
      name: json['name']?.toString() ?? 'Неизвестно',
      description: json['description']?.toString() ?? '',
      color: json['color']?.toString() ?? 'grey',
      canEdit: json['can_edit'] == true,
    );
  }
}

class AssignmentFile {
  final int id;
  final String fileName;
  final String fileUrl;
  final int? fileSize;
  final DateTime? uploadedAt;

  AssignmentFile({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.fileSize,
    this.uploadedAt,
  });

  factory AssignmentFile.fromJson(Map<String, dynamic> json) {
    return AssignmentFile(
      id: json['id'] ?? 0,
      fileName: json['file_name']?.toString() ?? 'Файл',
      fileUrl: json['file_url']?.toString() ?? json['file']?.toString() ?? '',
      fileSize: json['file_size'],
      uploadedAt: _parseDate(json['uploaded_at']),
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

class AssignmentDetail {
  final Assignment assignment;
  final List<AssignmentAttempt> attempts;
  final List<AssignmentFile> teacherFiles;
  final bool canSubmit;
  final bool canSubmitNew;
  final int currentAttemptsCount;

  AssignmentDetail({
    required this.assignment,
    required this.attempts,
    required this.teacherFiles,
    required this.canSubmit,
    required this.canSubmitNew,
    required this.currentAttemptsCount,
  });

  factory AssignmentDetail.fromJson(Map<String, dynamic> json) {
    final assignmentData = json['assignment'] ?? {};
    final attemptsData = json['attempts'] as List? ?? [];
    final teacherFilesData = json['teacher_files'] as List? ?? [];

    return AssignmentDetail(
      assignment: Assignment.fromJson(assignmentData),
      attempts: attemptsData.map((a) => AssignmentAttempt.fromJson(a)).toList(),
      teacherFiles: teacherFilesData.map((f) => AssignmentFile.fromJson(f)).toList(),
      canSubmit: json['can_submit'] == true,
      canSubmitNew: json['can_submit_new'] == true,
      currentAttemptsCount: json['current_attempts_count'] ?? 0,
    );
  }
}