import 'package:flutter/foundation.dart';

/// данный класс представляет избранные курсы
class FavoriteCourse {
  final int id;
  final String name;
  final String? description;
  final String price;
  final String? photoPath;
  final int hours;
  final bool hasCertificate;
  final double avgRating;
  final int studentCount;
  final String? categoryName;
  final DateTime addedAt;
  final bool isFree;

  FavoriteCourse({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.photoPath,
    required this.hours,
    required this.hasCertificate,
    required this.avgRating,
    required this.studentCount,
    this.categoryName,
    required this.addedAt,
    required this.isFree,
  });

  factory FavoriteCourse.fromJson(Map<String, dynamic> json) {
    return FavoriteCourse(
      id: json['id'] ?? 0,
      name: json['course_name'] ?? '',
      description: json['course_description'],
      price: json['course_price']?.toString() ?? '0',
      photoPath: json['course_photo_path'],
      hours: json['course_hours'] ?? 0,
      hasCertificate: json['has_certificate'] ?? false,
      avgRating: (json['avg_rating'] ?? 0).toDouble(),
      studentCount: json['student_count'] ?? 0,
      categoryName: json['category_name'],
      addedAt: DateTime.parse(json['added_at']),
      isFree: json['is_free'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_name': name,
      'course_description': description,
      'course_price': price,
      'course_photo_path': photoPath,
      'course_hours': hours,
      'has_certificate': hasCertificate,
      'avg_rating': avgRating,
      'student_count': studentCount,
      'category_name': categoryName,
      'added_at': addedAt.toIso8601String(),
      'is_free': isFree,
    };
  }
}