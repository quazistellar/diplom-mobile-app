// models/review.dart

class Review {
  final int id;
  final int courseId;
  final int userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime publishDate;
  final bool isApproved;

  Review({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.publishDate,
    required this.isApproved,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? 0,
      courseId: json['course'] ?? 0,
      userId: json['user'] ?? 0,
      userName: json['user_full_name'] ?? json['user_name'] ?? 'Пользователь',
      rating: json['rating'] ?? 0,
      comment: json['comment_review'] ?? '',
      publishDate: DateTime.parse(json['publish_date'] ?? DateTime.now().toIso8601String()),
      isApproved: json['is_approved'] ?? false,
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(publishDate);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} ${_getYearString((difference.inDays / 365).floor())} назад';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ${_getMonthString((difference.inDays / 30).floor())} назад';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${_getDayString(difference.inDays)} назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${_getHourString(difference.inHours)} назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${_getMinuteString(difference.inMinutes)} назад';
    } else {
      return 'только что';
    }
  }

  String _getYearString(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'год';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'года';
    return 'лет';
  }

  String _getMonthString(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'месяц';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'месяца';
    return 'месяцев';
  }

  String _getDayString(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'день';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'дня';
    return 'дней';
  }

  String _getHourString(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'час';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'часа';
    return 'часов';
  }

  String _getMinuteString(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'минуту';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'минуты';
    return 'минут';
  }
}