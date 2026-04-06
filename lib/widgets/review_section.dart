import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';
import '../utils/snackbar_helper.dart';

/// данный класс отображает секцию отзывов для курса
class ReviewSection extends StatefulWidget {
  final int courseId;
  final bool isAuthenticated;
  final bool isEnrolled;
  final double userProgress;
  final VoidCallback onReviewAdded;

  const ReviewSection({
    Key? key,
    required this.courseId,
    required this.isAuthenticated,
    required this.isEnrolled,
    required this.userProgress,
    required this.onReviewAdded,
  }) : super(key: key);

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final ApiClient _apiClient = ApiClient();
  
  bool _loadingReviews = false;
  bool _submittingReview = false;
  bool _editingReview = false;
  List<dynamic> _approvedReviews = [];
  int _selectedRating = 0;
  final TextEditingController _reviewTextController = TextEditingController();
  int? _currentUserId;
  Map<String, dynamic>? _userReview;
  bool _showReviewForm = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadReviews();
  }

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }

  /// данный метод загружает ID текущего пользователя
  Future<void> _loadCurrentUser() async {
    _currentUserId = await _apiClient.getUserId();
  }

  /// данный метод загружает отзывы о курсе
  Future<void> _loadReviews() async {
    if (_loadingReviews) return;
    
    setState(() => _loadingReviews = true);

    try {
      final token = await _apiClient.getToken();
      
      final response = await http.get(
        Uri.parse('${ApiClient.apiUrl}/reviews/?course=${widget.courseId}&format=json'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );
      
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final data = jsonDecode(decodedBody);
        
        final allReviews = List<dynamic>.from(data['results'] ?? []);
        
        final approved = allReviews.where((review) {
          return review['is_approved'] == true;
        }).toList();
        
        if (_currentUserId != null) {
          _userReview = approved.firstWhere(
            (review) {
              final userId = review['user'] ?? review['user_details']?['id'];
              return userId == _currentUserId;
            },
            orElse: () => null,
          );
        }
        
        setState(() {
          _approvedReviews = approved;
        });
      }
    } catch (e) {
      print('Error loading reviews: $e');
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  /// данный метод декодирует текст отзыва
  String _decodeText(String text) {
    try {
      if (text.startsWith('Р') || text.contains('Р')) {
        try {
          final latin1Bytes = latin1.encode(text);
          return utf8.decode(latin1Bytes, allowMalformed: true);
        } catch (e) {
          return text;
        }
      }
      return text;
    } catch (e) {
      return text;
    }
  }

  /// данный метод отправляет отзыв
  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      SnackBarHelper.showWarning(context, 'Пожалуйста, выберите рейтинг');
      return;
    }

    if (widget.userProgress < 50) {
      SnackBarHelper.showWarning(context, 
        'Вы можете оставить отзыв только после прохождения более 50% курса (сейчас: ${widget.userProgress.toStringAsFixed(1)}%)'
      );
      return;
    }

    if (_userReview != null && !_editingReview) {
      SnackBarHelper.showWarning(context, 'Вы можете оставить только один отзыв на курс');
      return;
    }

    setState(() => _submittingReview = true);

    try {
      final token = await _apiClient.getToken();
      if (token == null) throw Exception('Пользователь не авторизован');
      
      final userId = await _apiClient.getUserId();
      
      final reviewData = {
        'course': widget.courseId.toString(),
        'user': userId,
        'rating': _selectedRating,
        'is_approved': true,
      };
      
      if (_reviewTextController.text.isNotEmpty) {
        reviewData['comment_review'] = _reviewTextController.text;
      }
      
      http.Response response;
      
      if (_editingReview && _userReview != null) {
        final reviewId = _userReview!['id'];
        response = await http.put(
          Uri.parse('${ApiClient.apiUrl}/reviews/$reviewId/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(reviewData),
        );
      } else {
        response = await http.post(
          Uri.parse('${ApiClient.apiUrl}/reviews/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(reviewData),
        );
      }
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        _reviewTextController.clear();
        setState(() {
          _selectedRating = 0;
          _showReviewForm = false;
          _editingReview = false;
        });
        
        SnackBarHelper.showSuccess(
          context, 
          _editingReview ? 'Отзыв успешно обновлен!' : 'Ваш отзыв успешно отправлен!'
        );
        
        await _loadReviews();
        widget.onReviewAdded();
      } else {
        throw Exception('Ошибка отправки отзыва: ${response.statusCode}');
      }
      
    } catch (e) {
      SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _submittingReview = false);
    }
  }

  /// данный метод удаляет отзыв
  Future<void> _deleteReview() async {
    if (_userReview == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление отзыва'),
        content: const Text('Вы уверены, что хотите удалить свой отзыв?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submittingReview = true);

    try {
      final token = await _apiClient.getToken();
      if (token == null) throw Exception('Пользователь не авторизован');

      final reviewId = _userReview!['id'];
      final response = await http.delete(
        Uri.parse('${ApiClient.apiUrl}/reviews/$reviewId/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        setState(() {
          _userReview = null;
          _showReviewForm = false;
          _editingReview = false;
          _selectedRating = 0;
          _reviewTextController.clear();
        });
        
        SnackBarHelper.showSuccess(context, 'Отзыв успешно удален');
        await _loadReviews();
        widget.onReviewAdded();
      } else {
        throw Exception('Ошибка удаления отзыва');
      }
    } catch (e) {
      SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _submittingReview = false);
    }
  }

  /// данный метод начинает редактирование отзыва
  void _startEditing() {
    if (_userReview != null) {
      setState(() {
        _editingReview = true;
        _showReviewForm = true;
        _selectedRating = _userReview!['rating'] ?? 0;
        _reviewTextController.text = _userReview!['comment_review'] ?? '';
      });
    }
  }

  /// данный метод создает виджет звезд рейтинга
  Widget _buildRatingStars(int rating, {double size = 20, bool interactive = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: interactive ? () {
            setState(() => _selectedRating = index + 1);
          } : null,
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
        );
      }),
    );
  }

  /// данный метод создает виджет карточки отзыва
  Widget _buildReviewCard(Map<String, dynamic> review, ThemeData theme) {
    final username = review['user_details']?['username'] ?? 
                    review['user']?['username'] ?? 'Аноним';
    final rating = review['rating'] ?? 0;
    final comment = review['comment_review'];
    final publishDate = review['publish_date'] != null 
        ? DateTime.tryParse(review['publish_date'])?.toString().substring(0, 10) ?? ''
        : '';
    final isUserReview = _currentUserId != null && 
        (review['user'] ?? review['user_details']?['id']) == _currentUserId;
    
    final decodedUsername = _decodeText(username.toString());
    final decodedComment = comment != null ? _decodeText(comment.toString()) : null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        decodedUsername,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (isUserReview) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ваш отзыв',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  publishDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRatingStars(rating),
                if (isUserReview)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: theme.primaryColor,
                        onPressed: _startEditing,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        color: Colors.red,
                        onPressed: _deleteReview,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
              ],
            ),
            if (decodedComment != null && decodedComment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                decodedComment,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// данный метод создает форму добавления отзыва
  Widget _buildAddReviewForm(ThemeData theme) {
    final canReview = widget.userProgress >= 50;
    final isEditing = _editingReview;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Редактировать отзыв' : 'Оставить отзыв',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: widget.userProgress / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            canReview ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.userProgress.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canReview 
                        ? 'Вы можете оставить отзыв (прогресс ≥50%)' 
                        : 'Для оставления отзыва необходимо пройти более 50% курса',
                    style: TextStyle(
                      fontSize: 12,
                      color: canReview ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Рейтинг: ',
                      style: TextStyle(color: theme.hintColor),
                    ),
                    const SizedBox(width: 8),
                    _buildRatingStars(_selectedRating, interactive: canReview),
                    if (_selectedRating > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '$_selectedRating/5',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: _reviewTextController,
                  maxLines: 3,
                  maxLength: 2000,
                  enabled: canReview,
                  decoration: InputDecoration(
                    labelText: 'Текст отзыва (необязательно)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showReviewForm = false;
                            _editingReview = false;
                            _selectedRating = 0;
                            _reviewTextController.clear();
                          });
                        },
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_submittingReview || !canReview) ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _submittingReview
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEditing ? 'Обновить' : 'Отправить'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                Text(
                  'Примечание: отзыв будет виден сразу после отправки',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('=== ReviewSection DEBUG ===');
    print('isAuthenticated: ${widget.isAuthenticated}');
    print('isEnrolled: ${widget.isEnrolled}');
    print('userProgress: ${widget.userProgress}');
    
    final theme = Theme.of(context);
    final averageRating = _approvedReviews.isEmpty 
        ? 0.0 
        : _approvedReviews.map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / _approvedReviews.length;

    final hasUserReviewed = _userReview != null;
    final canAddReview = widget.isAuthenticated && 
                        widget.isEnrolled && 
                        widget.userProgress >= 50 && 
                        !hasUserReviewed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Отзывы',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            if (_approvedReviews.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${averageRating.toStringAsFixed(1)} (${_approvedReviews.length})',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_loadingReviews)
          const Center(child: CircularProgressIndicator())
        else if (_approvedReviews.isNotEmpty)
          Column(
            children: _approvedReviews.map<Widget>((review) {
              return _buildReviewCard(review, theme);
            }).toList(),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Center(
              child: Text(
                'Пока нет отзывов о курсе',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.hintColor,
                ),
              ),
            ),
          ),
        
        const SizedBox(height: 24),
        
        if (canAddReview && !_showReviewForm)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showReviewForm = true;
                  _editingReview = false;
                });
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('Оставить отзыв'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ),
        
        if (hasUserReviewed && !_showReviewForm)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Вы уже оставили отзыв на этот курс. Вы можете отредактировать или удалить его.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        
        if (_showReviewForm)
          _buildAddReviewForm(theme),
      ],
    );
  }
}