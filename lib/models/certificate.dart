import 'course.dart';

/// данный класс представляет модель сертификата
class Certificate {
  final int id;
  final String certificateNumber;
  final DateTime issueDate;
  final String? fileUrl;
  final Map<String, dynamic> rawData;

  Certificate({
    required this.id,
    required this.certificateNumber,
    required this.issueDate,
    this.fileUrl,
    required this.rawData,
  });

  /// данная функция создает объект сертификата из JSON
  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      id: json['id'] ?? 0,
      certificateNumber: json['certificate_number']?.toString() ?? 'Не указан',
      issueDate: _parseDate(json['issue_date']) ?? DateTime.now(),
      fileUrl: json['file']?.toString(),
      rawData: json,
    );
  }

  /// данная функция парсит дату из различных форматов
  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    try {
      return DateTime.parse(date.toString());
    } catch (_) {
      return null;
    }
  }

  /// данная функция возвращает отформатированную дату выдачи
  String get formattedDate {
    return '${issueDate.day.toString().padLeft(2, '0')}.${issueDate.month.toString().padLeft(2, '0')}.${issueDate.year}';
  }
}

/// данный класс представляет сертификат с информацией о курсе
class CertificateWithCourse {
  final Certificate certificate;
  final Course? course;

  CertificateWithCourse({
    required this.certificate,
    this.course,
  });

  /// данная функция создает объект сертификата с курсом из JSON
  factory CertificateWithCourse.fromJson(Map<String, dynamic> json) {
    return CertificateWithCourse(
      certificate: Certificate.fromJson(json['certificate'] ?? {}),
      course: json['course'] != null ? Course.fromJson(json['course']) : null,
    );
  }
}

/// данный класс представляет результат проверки возможности получения сертификата
class CertificateEligibility {
  final bool eligible;
  final String? message;
  final Course? course;

  CertificateEligibility({
    required this.eligible,
    this.message,
    this.course,
  });

  /// данная функция создает объект проверки возможности получения сертификата из JSON
  factory CertificateEligibility.fromJson(Map<String, dynamic> json) {
    return CertificateEligibility(
      eligible: json['eligible'] == true,
      message: json['message']?.toString(),
      course: json['course'] != null ? Course.fromJson(json['course']) : null,
    );
  }
}