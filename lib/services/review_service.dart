import 'package:unireax_mobile_diplom/services/api_client.dart';

/// данный класс предоставляет сервис для работы с отзывами
class ReviewService {
  final ApiClient _apiClient = ApiClient();

  /// данная функция отправляет отзыв на курс
  Future<void> submitReview(int courseId, int rating, String comment) async {
    try {
      final userId = await _apiClient.getUserId();
      if (userId == null) throw Exception('Требуется авторизация');

      await _apiClient.post(
        '/reviews/',
        data: {
          'course': courseId,
          'user': userId,
          'rating': rating,
          'comment_review': comment,
        },
      );
    } catch (e) {
      throw Exception('Ошибка при отправке отзыва');
    }
  }
}