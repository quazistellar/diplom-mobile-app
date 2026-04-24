// данный класс представляет модель поста в курсе
class CoursePost {
  final int id;
  final String title;
  final String content;
  final String postType;
  final String postTypeDisplay;
  final bool isPinned;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int authorId;
  final String authorName;
  final String authorRole;
  final int courseId;
  final int commentsCount;
  final bool canEdit;
  final bool canDelete;
  final List<CoursePostComment> comments;

  CoursePost({
    required this.id,
    required this.title,
    required this.content,
    required this.postType,
    required this.postTypeDisplay,
    required this.isPinned,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.courseId,
    required this.commentsCount,
    required this.canEdit,
    required this.canDelete,
    required this.comments,
  });

  factory CoursePost.fromJson(Map<String, dynamic> json) {
    return CoursePost(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      postType: json['post_type'] ?? 'announcement',
      postTypeDisplay: json['post_type_display'] ?? 'Объявление',
      isPinned: json['is_pinned'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      authorId: json['author'] ?? 0,
      authorName: json['author_name'] ?? '',
      authorRole: json['author_role'] ?? '',
      courseId: json['course'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      canEdit: json['can_edit'] ?? false,
      canDelete: json['can_delete'] ?? false,
      comments: (json['comments'] as List?)
          ?.map((c) => CoursePostComment.fromJson(c))
          .toList() ?? [],
    );
  }
}

class CoursePostComment {
  final int id;
  final String content;
  final DateTime createdAt;
  final int authorId;
  final String authorName;
  final String authorRole;
  final int? parentId;
  final bool canDelete;
  List<CoursePostComment> replies; 

  CoursePostComment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    this.parentId,
    required this.canDelete,
    required this.replies,
  });

  factory CoursePostComment.fromJson(Map<String, dynamic> json) {
    return CoursePostComment(
      id: json['id'],
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      authorId: json['author'] ?? 0,
      authorName: json['author_name'] ?? '',
      authorRole: json['author_role'] ?? '',
      parentId: json['parent'],
      canDelete: json['can_delete'] ?? false,
      replies: (json['replies'] as List?)
          ?.map((r) => CoursePostComment.fromJson(r))
          .toList() ?? [],
    );
  }
}