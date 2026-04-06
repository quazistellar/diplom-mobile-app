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

  Object? toJson() {}
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
}

/// данный класс представляет тип курса
class CourseType {
  final int id;
  final String name;

  CourseType({required this.id, required this.name});

  /// данная функция создает объект типа из JSON
  factory CourseType.fromJson(Map<String, dynamic> json) {
    return CourseType(
      id: json['id'] ?? 0,
      name: json['course_type_name']?.toString() ?? 'Тип',
    );
  }
}