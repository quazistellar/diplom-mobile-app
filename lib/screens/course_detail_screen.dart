import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_course_provider.dart';
import '../services/api_client.dart';
import '../services/payment_service.dart';
import '../models/course.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/review_section.dart';
import 'course_materials_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  final Map<String, dynamic> courseData;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseData,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  bool _loadingReviews = false;
  bool _loadingMaterials = false;
  List<dynamic> _reviews = [];
  List<dynamic> _lectures = [];
  List<dynamic> _tests = [];
  List<dynamic> _assignments = [];
  double _completionPercentage = 0.0;
  bool _hasLoadedCompletion = false;
  
  List<dynamic> _approvedReviews = [];
  late Course _course;

  @override
  void initState() {
    super.initState();
    _course = Course.fromJson(widget.courseData);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
      _loadCourseMaterials();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _decodeReviewText(String text) {
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

  String _getCourseStatus() {
    if (!_course.isActive) return 'Неактивен';
    return 'Активен';
  }

  Color _getStatusColor() {
    if (!_course.isActive) return Colors.red;
    return Colors.green;
  }

  String _getCompletionText() {
    return _course.isCompleted == true ? 'Завершено' : 'Пополняется';
  }

  Color _getCompletionColor() {
    return _course.isCompleted == true ? Colors.green : Colors.orange;
  }

  String _getMaxPlacesText() {
    if (_course.maxPlaces == null) return 'Неограниченно';
    return '${_course.maxPlaces} мест';
  }

  String _getCertificateText() {
    return _course.hasCertificate ? 'Предусмотрен' : 'Не предусмотрен';
  }

  Color _getCertificateColor() {
    return _course.hasCertificate ? Colors.green : Colors.grey;
  }

  Future<void> _payForCourse(AuthProvider authProvider) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      if (_course.isFree) {
        SnackBarHelper.showWarning(context, 'Этот курс бесплатный. Используйте кнопку "Записаться бесплатно"');
        return;
      }
      
      final paymentResult = await _apiClient.post<Map<String, dynamic>>(
        '/payments/create/${widget.courseId}/'
      );
      
      print('📦 Payment result: $paymentResult');
      
      if (paymentResult['success'] == true) {
        final paymentId = paymentResult['payment_id']?.toString();
        final paymentUrl = paymentResult['confirmation_url'];
        final amount = paymentResult['amount'] ?? _course.price.toString();
        
        print('✅ Создан платеж: $paymentId');
        print('🔗 URL: $paymentUrl');
        
        if (paymentId == null || paymentId.isEmpty) {
          throw Exception('Не удалось получить ID платежа');
        }
        
        await PaymentService.openYookassaPayment(
          context: context,
          paymentUrl: paymentUrl,
          paymentId: paymentId,
          courseId: widget.courseId,
          courseName: _course.name,
          amount: double.parse(amount.toString()),
          onComplete: (success, message, returnedPaymentId) async {
            print('🔙 Payment complete: success=$success, paymentId=$returnedPaymentId');
            
            if (success) {
              await authProvider.refreshUserData();
              await context.read<UserCourseProvider>().loadUserCourses();
              
              if (mounted) {
                SnackBarHelper.showSuccess(
                  context, 
                  'Курс успешно оплачен и активирован!\nID платежа: $returnedPaymentId'
                );
                setState(() {});
              }
            } else if (message != null && mounted) {
              SnackBarHelper.showError(context, 'Ошибка: $message');
            }
          },
        );
      } else {
        final errorMessage = paymentResult['detail'] ?? 'Неизвестная ошибка создания платежа';
        throw Exception(errorMessage);
      }
      
    } catch (e) {
      print('❌ Payment error: $e');
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      if (mounted) {
        SnackBarHelper.showError(context, 'Ошибка оплаты: $errorMessage');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enrollToCourse(AuthProvider authProvider) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      await context.read<UserCourseProvider>().enrollToCourse(widget.courseId);
      
      SnackBarHelper.showSuccess(context, 'Вы успешно записались на курс "${_course.name}"');
      
      await _loadCompletionPercentage(authProvider);
      
      if (mounted) setState(() {});
      
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        SnackBarHelper.showError(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    if (_loadingReviews) return;
    
    setState(() => _loadingReviews = true);

    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/reviews/',
        queryParams: {'course': widget.courseId.toString()},
        isPublic: true,
      );
      
      final allReviews = List<dynamic>.from(data['results'] ?? []);
      
      final approved = allReviews.where((review) {
        return review['is_approved'] == true;
      }).toList();
      
      for (var review in approved) {
        if (review['comment_review'] != null) {
          review['comment_review'] = _decodeReviewText(review['comment_review'].toString());
        }
      }
      
      setState(() {
        _reviews = allReviews;
        _approvedReviews = approved;
      });
    } catch (e) {
      print('Error loading reviews: $e');
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  Future<void> _loadCourseMaterials() async {
    if (_loadingMaterials) return;
    
    setState(() => _loadingMaterials = true);

    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/courses/${widget.courseId}/materials/',
        isPublic: true,
      );
      
      setState(() {
        _lectures = [];
        _tests = [];
        _assignments = [];
        
        final materials = data['materials_by_lecture'] as List? ?? [];
        
        for (var lectureData in materials) {
          final lecture = lectureData['lecture'];
          if (lecture != null) {
            _lectures.add({
              'id': lecture['id'] ?? 0,
              'name': lecture['name'] ?? 'Лекция ${lecture['order'] ?? ''}',
              'order': lecture['order'] ?? 0,
            });
          }
          
          final assignments = lectureData['assignments'] as List? ?? [];
          for (var assignment in assignments) {
            _assignments.add({
              'id': assignment['id'] ?? 0,
              'name': assignment['name'] ?? 'Задание',
              'lecture_id': lecture?['id'] ?? 0,
            });
          }
          
          final tests = lectureData['tests'] as List? ?? [];
          for (var test in tests) {
            _tests.add({
              'id': test['id'] ?? 0,
              'name': test['name'] ?? 'Тест',
              'lecture_id': lecture?['id'] ?? 0,
            });
          }
        }
      });
    } catch (e) {
      print('Ошибка загрузки материалов: $e');
    } finally {
      setState(() => _loadingMaterials = false);
    }
  }

  Future<void> _loadCompletionPercentage(AuthProvider authProvider) async {
    if (_hasLoadedCompletion) return;
    
    try {
      if (!authProvider.isAuthenticated) return;
      
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/courses/${widget.courseId}/completion/',
      );
      
      final completion = data['completion'] is int 
          ? (data['completion'] as int).toDouble()
          : (data['completion']?.toDouble() ?? 0.0);
      
      setState(() {
        _completionPercentage = completion;
        _hasLoadedCompletion = true;
      });
    } catch (e) {
      print('Error loading completion: $e');
    }
  }

  Future<void> _showEnrollAgainDialog(BuildContext context, AuthProvider authProvider) async {
    final shouldEnroll = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Записаться на курс'),
        content: Text('Хотите записаться на курс "${_course.name}" снова?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Записаться'),
          ),
        ],
      ),
    );

    if (shouldEnroll == true) {
      await _enrollToCourse(authProvider);
    }
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required ThemeData theme,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.primaryColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseMaterials() {
    if (_loadingMaterials) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_lectures.isEmpty && _tests.isEmpty && _assignments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Материалы курса',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        ..._lectures.map((lecture) {
          final lectureId = lecture['id'] ?? 0;
          final lectureName = lecture['name'] ?? 'Лекция';
          final lectureOrder = lecture['order'] ?? 0;
          
          final lectureAssignments = _assignments
              .where((a) => a['lecture_id'] == lectureId)
              .toList();
          
          final lectureTests = _tests
              .where((t) => t['lecture_id'] == lectureId)
              .toList();
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    '$lectureOrder',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                title: Text(
                  lectureName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                children: [
                  if (lectureAssignments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lectureAssignments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                        itemBuilder: (context, index) {
                          final assignment = lectureAssignments[index];
                          return ListTile(
                            leading: const Icon(Icons.assignment_outlined, size: 20, color: Colors.orange),
                            title: Text(
                              assignment['name'] ?? 'Задание',
                              style: const TextStyle(fontSize: 14),
                            ),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          );
                        },
                      ),
                    ),
                  
                  if (lectureTests.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lectureTests.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                        itemBuilder: (context, index) {
                          final test = lectureTests[index];
                          return ListTile(
                            leading: const Icon(Icons.quiz_outlined, size: 20, color: Colors.green),
                            title: Text(
                              test['name'] ?? 'Тест',
                              style: const TextStyle(fontSize: 14),
                            ),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          );
                        },
                      ),
                    ),
                  
                  if (lectureAssignments.isEmpty && lectureTests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Нет материалов',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
        
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation ?? 2,
        title: const Text('Детали курса'),
      ),
      body: Consumer2<AuthProvider, UserCourseProvider>(
        builder: (context, authProvider, userCourseProvider, child) {
          
          final isUserAuthenticated = authProvider.isAuthenticated;
          final isUserEnrolled = userCourseProvider.isUserEnrolled(widget.courseId);
          final isUserActiveEnrolled = userCourseProvider.isUserActiveEnrolled(widget.courseId);
          
          if (isUserAuthenticated && isUserEnrolled && !_hasLoadedCompletion) {
            _loadCompletionPercentage(authProvider);
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_course.photoPath != null && _course.photoPath!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _apiClient.getImageUrl(_course.photoPath),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: theme.colorScheme.surface,
                          child: const Icon(Icons.image, size: 50, color: Colors.grey),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: theme.colorScheme.surface,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                
                if (_course.photoPath != null && _course.photoPath!.isNotEmpty)
                  const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _course.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_course.rating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              _course.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Wrap(
                  spacing: 8,
                  children: [
                    if (_course.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _course.category!.name,
                          style: TextStyle(fontSize: 12, color: theme.primaryColor),
                        ),
                      ),
                    if (_course.type != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _course.type!.name,
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  _course.description ?? 'Описание отсутствует',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.hintColor,
                    height: 1.6,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildDetailCard(
                      icon: Icons.timer,
                      title: 'Длительность',
                      value: '${_course.hours} ч',
                      theme: theme,
                    ),
                    
                    _buildDetailCard(
                      icon: Icons.people,
                      title: 'Студентов',
                      value: '${_course.rawData['enrolled_count'] ?? 0}',
                      theme: theme,
                    ),
                    
                    _buildDetailCard(
                      icon: Icons.event_seat,
                      title: 'Макс. мест',
                      value: _getMaxPlacesText(),
                      theme: theme,
                    ),
                    
                    _buildDetailCard(
                      icon: Icons.attach_money,
                      title: 'Стоимость',
                      value: _course.displayPrice,
                      theme: theme,
                    ),
                    
                    _buildDetailCard(
                      icon: _course.hasCertificate ? Icons.verified : Icons.cancel_outlined,
                      title: 'Сертификат',
                      value: _getCertificateText(),
                      theme: theme,
                      valueColor: _getCertificateColor(),
                    ),
                    
                    _buildDetailCard(
                      icon: Icons.info_outline,
                      title: 'Статус курса',
                      value: _getCourseStatus(),
                      theme: theme,
                      valueColor: _getStatusColor(),
                    ),
                    
                    _buildDetailCard(
                      icon: _course.isCompleted == true ? Icons.check_circle : Icons.autorenew,
                      title: 'Наполнение',
                      value: _getCompletionText(),
                      theme: theme,
                      valueColor: _getCompletionColor(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                _buildCourseMaterials(),
                
                ReviewSection(
                  courseId: widget.courseId,
                  isAuthenticated: isUserAuthenticated,
                  isEnrolled: isUserEnrolled,
                  userProgress: _completionPercentage,
                  onReviewAdded: () {
                    _loadReviews();
                  },
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.primaryColor),
                        ),
                        child: const Text('Назад'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    if (!isUserAuthenticated)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            SnackBarHelper.showWarning(context, 'Для записи на курс необходимо войти в систему');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login, size: 20),
                              SizedBox(width: 8),
                              Text('Войти'),
                            ],
                          ),
                        ),
                      )
                    else if (!isUserEnrolled)
                      Expanded(
                        child: _course.isFree
                            ? ElevatedButton(
                                onPressed: _isLoading ? null : () => _enrollToCourse(authProvider),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Записаться'),
                              )
                            : ElevatedButton(
                                onPressed: _isLoading ? null : () => _payForCourse(authProvider),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.payment, size: 20),
                                          SizedBox(width: 8),
                                          Text('Оплатить'),
                                        ],
                                      ),
                              ),
                      )
                    else if (isUserActiveEnrolled)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CourseMaterialsScreen(courseId: widget.courseId),
                              ),
                        );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow, size: 20),
                              SizedBox(width: 8),
                              Text('Продолжить'),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showEnrollAgainDialog(context, authProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, size: 20),
                              SizedBox(width: 8),
                              Text('Вернуться'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}