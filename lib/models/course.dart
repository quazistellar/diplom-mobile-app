import 'dart:convert';
import 'package:flutter/foundation.dart';

/// данный класс представляет модель курса
class Course {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int hours;
  final bool hasCertificate;
  final int? maxPlaces;
  final double rating;
  final String? photoPath;
  final CourseCategory? category;
  final CourseType? type;
  final bool isActive;
  final int? userCourseId;
  final bool? isCompleted;
  final bool? isEnrolled;
  final String? paymentId;      
  final bool? isActiveEnrollment;
  final String? paymentDate;
  final String? meetingLink;
  final Map<String, dynamic> rawData;

  Course({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.hours,
    this.isActiveEnrollment,
    required this.hasCertificate,
    this.maxPlaces,
    required this.rating,
    this.photoPath,
    this.category,
    this.type,
    this.isActive = true,
    this.isCompleted,
    this.userCourseId, 
    this.isEnrolled,
    this.paymentId,              
    this.paymentDate,
    this.meetingLink,
    required this.rawData,
  });

  /// данная функция создает объект курса из JSON
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['course_name']?.toString() ?? 'Без названия',
      description: json['course_description']?.toString(),
      price: _parsePrice(json['course_price']),
      hours: _parseInt(json['course_hours']),
      hasCertificate: json['has_certificate'] == true,
      maxPlaces: _parseInt(json['course_max_places']),
      rating: _parseRating(json),
      photoPath: json['course_photo_path']?.toString(),
      category: json['category_details'] != null 
          ? CourseCategory.fromJson(json['category_details'])
          : null,
      type: json['type_details'] != null
          ? CourseType.fromJson(json['type_details'])
          : null,
      isActive: json['is_active'] == true,
      isCompleted: json['is_completed'],
      isEnrolled: json['is_enrolled'],
      paymentId: json['payment_id']?.toString(),       
      paymentDate: json['payment_date']?.toString(),
      meetingLink: json['code_link']?.toString(),
      rawData: json,
    );
  }

  /// данная функция парсит цену из различных форматов
  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      if (value.isEmpty) return 0.0;
      final cleaned = value.replaceAll('"', '').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  /// данная функция парсит целое число из различных форматов
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return 0;
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  /// данная функция парсит рейтинг из различных полей
  static double _parseRating(Map<String, dynamic> json) {
    final rating = json['calculated_rating'] ?? 
                   json['average_rating'] ?? 
                   json['rating'] ?? 
                   json['avg_rating'] ?? 0.0;
    if (rating is int) return rating.toDouble();
    if (rating is double) return rating;
    if (rating is String) return double.tryParse(rating) ?? 0.0;
    return 0.0;
  }

  /// данная функция проверяет, является ли курс бесплатным
  bool get isFree => price == 0;
  
  /// данная функция возвращает отформатированную цену
  String get displayPrice => isFree ? 'Бесплатно' : '${price.toStringAsFixed(2)} ₽';

  /// данная функция создает JSON из объекта
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_name': name,
      'course_description': description,
      'course_price': price,
      'course_hours': hours,
      'has_certificate': hasCertificate,
      'course_max_places': maxPlaces,
      'course_photo_path': photoPath,
      'is_active': isActive,
      'is_completed': isCompleted,
      'is_enrolled': isEnrolled,
      'payment_id': paymentId,
      'payment_date': paymentDate,
      'code_link': meetingLink,
      'category_details': category?.toJson(),
      'type_details': type?.toJson(),
    };
  }

  /// данная функция создает копию курса с измененными полями
  Course copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    int? hours,
    bool? hasCertificate,
    int? maxPlaces,
    double? rating,
    String? photoPath,
    CourseCategory? category,
    CourseType? type,
    bool? isActive,
    bool? isCompleted,
    bool? isEnrolled,
    String? paymentId,
    String? paymentDate,
    String? meetingLink,
    Map<String, dynamic>? rawData,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      hours: hours ?? this.hours,
      hasCertificate: hasCertificate ?? this.hasCertificate,
      maxPlaces: maxPlaces ?? this.maxPlaces,
      rating: rating ?? this.rating,
      photoPath: photoPath ?? this.photoPath,
      category: category ?? this.category,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      paymentId: paymentId ?? this.paymentId,
      paymentDate: paymentDate ?? this.paymentDate,
      meetingLink: meetingLink ?? this.meetingLink,
      rawData: rawData ?? this.rawData,
    );
  }

  @override
  String toString() {
    return 'Course(id: $id, name: $name, price: $price, hours: $hours, meetingLink: $meetingLink)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// данный класс представляет категорию курса
class CourseCategory {
  final int id;
  final String name;

  CourseCategory({required this.id, required this.name});

  /// данная функция создает объект категории из JSON
  factory CourseCategory.fromJson(Map<String, dynamic> json) {
    return CourseCategory(
      id: json['id'] ?? 0,
      name: json['course_category_name']?.toString() ?? 'Категория',
    );
  }

  /// данная функция создает JSON из объекта
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_category_name': name,
    };
  }

  @override
  String toString() => 'CourseCategory(id: $id, name: $name)';
}

/// данный класс представляет тип курса
class CourseType {
  final int id;
  final String name;
  final String? description;

  CourseType({
    required this.id, 
    required this.name,
    this.description,
  });

  /// данная функция создает объект типа из JSON
  factory CourseType.fromJson(Map<String, dynamic> json) {
    return CourseType(
      id: json['id'] ?? 0,
      name: json['course_type_name']?.toString() ?? 'Тип',
      description: json['course_type_description']?.toString(),
    );
  }

  /// данная функция создает JSON из объекта
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_type_name': name,
      'course_type_description': description,
    };
  }

  @override
  String toString() => 'CourseType(id: $id, name: $name)';
}