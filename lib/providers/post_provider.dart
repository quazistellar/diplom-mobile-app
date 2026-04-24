import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/api_client.dart';

class PostProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<CoursePost> _posts = [];
  int _unreadCount = 0;
  int _totalCount = 0;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<CoursePost> get posts => _posts;
  int get unreadCount => _unreadCount;
  int get totalCount => _totalCount;

  /// данная функция устанавливает загрузку
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
 
  /// данная функция устанавливает подтверждение (статус)
  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }
 
  /// данная функция очищает сообщение об ошибке
  void _clearError() {
    _errorMessage = null;
  }

  /// данная функция выполняет загрузку постов курса
  Future<void> loadPosts(int courseId) async {
    _setLoading(true);
    _clearError();

    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/posts/by-course/$courseId/',
      );
            
      final postsData = data['results'] as List? ?? [];
      _posts = postsData.map((json) => CoursePost.fromJson(json)).toList();
      _unreadCount = 0; 
      _totalCount = data['count'] ?? 0;      
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _posts = [];
      _unreadCount = 0;
      _totalCount = 0;
    } finally {
      _setLoading(false);
    }
  }
  /// данная функция выполняет функцию создания поста 
  Future<CoursePost?> createPost({
    required int courseId,
    required String title,
    required String content,
    String postType = 'announcement',
    bool isPinned = false,
  }) async {
    _setSubmitting(true);
    _clearError();

    try {
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/posts/create/',
        data: {
          'course_id': courseId,
          'title': title,
          'content': content,
          'post_type': postType,
          'is_pinned': isPinned,
        },
      );
      
      final post = CoursePost.fromJson(data);
      _posts.insert(0, post);
      _totalCount++;
      notifyListeners();
      
      return post;
    } catch (e) {
      _errorMessage = e.toString();
      print('Ошибка создания поста: $e');
      return null;
    } finally {
      _setSubmitting(false);
    }
  }

  /// данная функция выполняет добавление комментария к посту
  Future<CoursePostComment?> addComment({
    required int postId,
    required String content,
    int? parentId,
  }) async {
    _setSubmitting(true);
    _clearError();

    try {;
      
      final Map<String, dynamic> requestData = {
        'content': content,
      };
      
      if (parentId != null) {
        requestData['parent'] = parentId;
      }
            
      final data = await _apiClient.post<Map<String, dynamic>>(
        '/posts/$postId/comment/',
        data: requestData,
      );
      
      
      final newComment = CoursePostComment.fromJson(data);
      
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        
        if (parentId == null) {
          final updatedComments = [newComment, ...post.comments];
          final updatedPost = CoursePost(
            id: post.id,
            title: post.title,
            content: post.content,
            postType: post.postType,
            postTypeDisplay: post.postTypeDisplay,
            isPinned: post.isPinned,
            isActive: post.isActive,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt,
            authorId: post.authorId,
            authorName: post.authorName,
            authorRole: post.authorRole,
            courseId: post.courseId,
            commentsCount: post.commentsCount + 1,
            canEdit: post.canEdit,
            canDelete: post.canDelete,
            comments: updatedComments,
          );
          _posts[postIndex] = updatedPost;
        } else {
          final updatedComments = _updateRepliesInComments(post.comments, parentId, newComment);
          final updatedPost = CoursePost(
            id: post.id,
            title: post.title,
            content: post.content,
            postType: post.postType,
            postTypeDisplay: post.postTypeDisplay,
            isPinned: post.isPinned,
            isActive: post.isActive,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt,
            authorId: post.authorId,
            authorName: post.authorName,
            authorRole: post.authorRole,
            courseId: post.courseId,
            commentsCount: post.commentsCount + 1,
            canEdit: post.canEdit,
            canDelete: post.canDelete,
            comments: updatedComments,
          );
          _posts[postIndex] = updatedPost;
        }
        notifyListeners();
      }
      
      return newComment;
    } catch (e) {
      _errorMessage = e.toString();
      
      if (e is DioException) {
        print('ошибка : ${e.response?.statusCode}');
      }
      
      return null;
    } finally {
      _setSubmitting(false);
    }
  }


  // создание нового объека комментария с обновленными ответами
  List<CoursePostComment> _updateRepliesInComments(
    List<CoursePostComment> comments,
    int parentId,
    CoursePostComment newReply,
  ) {
    return comments.map((comment) {
      if (comment.id == parentId) {
        return CoursePostComment(
          id: comment.id,
          content: comment.content,
          createdAt: comment.createdAt,
          authorId: comment.authorId,
          authorName: comment.authorName,
          authorRole: comment.authorRole,
          parentId: comment.parentId,
          canDelete: comment.canDelete,
          replies: [...comment.replies, newReply],
        );
      }
      final updatedReplies = _updateRepliesInComments(comment.replies, parentId, newReply);
      if (updatedReplies != comment.replies) {
        return CoursePostComment(
          id: comment.id,
          content: comment.content,
          createdAt: comment.createdAt,
          authorId: comment.authorId,
          authorName: comment.authorName,
          authorRole: comment.authorRole,
          parentId: comment.parentId,
          canDelete: comment.canDelete,
          replies: updatedReplies,
        );
      }
      return comment;
    }).toList();
  }

  /// данная функция выполняет удаление комментария
  Future<bool> deleteComment(int postId, int commentId) async {
    _setSubmitting(true);
    _clearError();

    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/posts/$postId/delete-comment/$commentId/',
        data: {},
      );
      
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        final updatedComments = _removeCommentFromList(post.comments, commentId);
        final updatedPost = CoursePost(
          id: post.id,
          title: post.title,
          content: post.content,
          postType: post.postType,
          postTypeDisplay: post.postTypeDisplay,
          isPinned: post.isPinned,
          isActive: post.isActive,
          createdAt: post.createdAt,
          updatedAt: post.updatedAt,
          authorId: post.authorId,
          authorName: post.authorName,
          authorRole: post.authorRole,
          courseId: post.courseId,
          commentsCount: post.commentsCount - 1,
          canEdit: post.canEdit,
          canDelete: post.canDelete,
          comments: updatedComments,
        );
        _posts[postIndex] = updatedPost;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  List<CoursePostComment> _removeCommentFromList(
    List<CoursePostComment> comments,
    int commentId,
  ) {
    return comments.where((comment) {
      return comment.id != commentId;
    }).map((comment) {
      final updatedReplies = _removeCommentFromList(comment.replies, commentId);
      if (updatedReplies != comment.replies) {
        return CoursePostComment(
          id: comment.id,
          content: comment.content,
          createdAt: comment.createdAt,
          authorId: comment.authorId,
          authorName: comment.authorName,
          authorRole: comment.authorRole,
          parentId: comment.parentId,
          canDelete: comment.canDelete,
          replies: updatedReplies,
        );
      }
      return comment;
    }).toList();
  }

  /// данная функция выполняет очистку сообщения об ошибке
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}