import 'package:unireax_mobile_diplom/models/assignment.dart';
import 'package:unireax_mobile_diplom/models/test.dart';

/// данный класс представляет прогресс по курсу
class CourseProgress {
  final int courseId;
  final String courseName;
  final String? courseDescription;
  final double progress;
  final bool isCompleted;
  final int? hours;
  final String? category;
  final bool hasCertificate;
  final Map<String, dynamic> rawData;

  CourseProgress({
    required this.courseId,
    required this.courseName,
    this.courseDescription,
    required this.progress,
    required this.isCompleted,
    this.hours,
    this.category,
    this.hasCertificate = false,
    required this.rawData,
  });

  /// данная функция создает объект прогресса курса из JSON
  factory CourseProgress.fromJson(Map<String, dynamic> json) {
    return CourseProgress(
      courseId: json['id'] ?? 0,
      courseName: json['name']?.toString() ?? json['course_name']?.toString() ?? 'Без названия',
      courseDescription: json['description']?.toString() ?? json['course_description']?.toString(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      isCompleted: json['is_completed'] == true,
      hours: json['hours'] ?? json['course_hours'],
      category: json['category']?.toString() ?? json['course_category_name']?.toString(),
      hasCertificate: json['has_certificate'] == true,
      rawData: json,
    );
  }
}

/// данный класс представляет лекцию с материалами (заданиями и тестами)
class LectureWithMaterials {
  final Lecture lecture;
  final List<Assignment> assignments;
  final List<Test> tests;

  LectureWithMaterials({
    required this.lecture,
    required this.assignments,
    required this.tests,
  });

  /// данная функция создает объект лекции с материалами из json
  factory LectureWithMaterials.fromJson(Map<String, dynamic> json) {
    return LectureWithMaterials(
      lecture: Lecture.fromJson(json['lecture'] ?? {}),
      assignments: (json['assignments'] as List? ?? [])
          .map((a) => Assignment.fromJson(a))
          .toList(),
      tests: (json['tests'] as List? ?? [])
          .map((t) => Test.fromJson(t))
          .toList(),
    );
  }
}

/// данный класс представляет лекцию
class Lecture {
  final int id;
  final String name;
  final String? content;
  final String? documentPath;
  final int order;

  Lecture({
    required this.id,
    required this.name,
    this.content,
    this.documentPath,
    required this.order,
  });

  /// данная функция создает объект лекции из json
  factory Lecture.fromJson(Map<String, dynamic> json) {
    return Lecture(
      id: json['id'] ?? 0,
      name: json['lecture_name']?.toString() ?? 'Без названия',
      content: json['lecture_content']?.toString(),
      documentPath: json['lecture_document_path']?.toString(),
      order: json['lecture_order'] ?? 0,
    );
  }
}

/// данный класс представляет сводную статистику
class StatisticsSummary {
  final int totalCourses;
  final int completedCourses;
  final double completionRate;
  final int certificatesCount;
  final int assignmentsTotal;
  final int assignmentsCompleted;
  final double assignmentsPercentage;
  final int testsTotal;
  final int testsPassed;
  final double testsPercentage;

  StatisticsSummary({
    required this.totalCourses,
    required this.completedCourses,
    required this.completionRate,
    required this.certificatesCount,
    required this.assignmentsTotal,
    required this.assignmentsCompleted,
    required this.assignmentsPercentage,
    required this.testsTotal,
    required this.testsPassed,
    required this.testsPercentage,
  });

  /// данная функция создает объект сводной статистики из json
  factory StatisticsSummary.fromJson(Map<String, dynamic> json) {
    final stats = json['statistics'] ?? json;
    
    final assignments = stats['assignments'] ?? {};
    final tests = stats['tests'] ?? {};

    return StatisticsSummary(
      totalCourses: stats['total_courses'] ?? 0,
      completedCourses: stats['completed_courses'] ?? 0,
      completionRate: (stats['completion_rate'] as num?)?.toDouble() ?? 0.0,
      certificatesCount: stats['certificates_count'] ?? 0,
      assignmentsTotal: assignments['total'] ?? 0,
      assignmentsCompleted: assignments['completed'] ?? 0,
      assignmentsPercentage: (assignments['percentage'] as num?)?.toDouble() ?? 0.0,
      testsTotal: tests['total'] ?? 0,
      testsPassed: tests['passed'] ?? 0,
      testsPercentage: (tests['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}