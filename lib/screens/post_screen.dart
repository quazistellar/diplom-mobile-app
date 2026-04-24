import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/post_provider.dart';
import '../models/post.dart';
import '../utils/snackbar_helper.dart';


/// данный класс реализует экран постов курса
class PostsScreen extends StatefulWidget {
  final int courseId;
  final String courseName;
  final bool isTeacher;

  const PostsScreen({
    Key? key,
    required this.courseId,
    required this.courseName,
    this.isTeacher = false,
  }) : super(key: key);

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final TextEditingController _postTitleController = TextEditingController();
  final TextEditingController _postContentController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  
  String _selectedPostType = 'announcement';
  bool _isPinned = false;
  int? _replyingToCommentId;
  String? _replyingToAuthorName;
  
  bool _isCreatePostFormVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPosts();
    });
  }

  @override
  void dispose() {
    _postTitleController.dispose();
    _postContentController.dispose();
    _commentController.dispose();
    super.dispose();
  }
 

  /// данная функция загружает посты курса
  Future<void> _loadPosts() async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    await postProvider.loadPosts(widget.courseId);
    if (mounted) {
      setState(() {});
    }
  }

  void _showCreatePostForm() {
    setState(() {
      _isCreatePostFormVisible = true;
      _postTitleController.clear();
      _postContentController.clear();
      _selectedPostType = 'announcement';
      _isPinned = false;
    });
  }

  void _hideCreatePostForm() {
    setState(() {
      _isCreatePostFormVisible = false;
    });
  }

  Future<void> _submitPost() async {
    final title = _postTitleController.text.trim();
    final content = _postContentController.text.trim();
    
    if (title.isEmpty) {
      SnackBarHelper.showError(context, 'Введите заголовок');
      return;
    }
    if (content.isEmpty) {
      SnackBarHelper.showError(context, 'Введите содержание');
      return;
    }
    
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final success = await postProvider.createPost(
      courseId: widget.courseId,
      title: title,
      content: content,
      postType: _selectedPostType,
      isPinned: _isPinned,
    );
    
    if (success != null) {
      _hideCreatePostForm();
      SnackBarHelper.showSuccess(context, 'Пост создан');
      await _loadPosts();
    } else {
      SnackBarHelper.showError(context, postProvider.errorMessage ?? 'Ошибка создания');
    }
  }

  /// данная функция отправляет комментарий
  Future<void> _submitComment(int postId, {int? parentId, String? parentAuthorName}) async {
    final content = _commentController.text.trim();
    
    if (content.isEmpty) {
      SnackBarHelper.showError(context, 'Введите комментарий');
      return;
    }
    
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final success = await postProvider.addComment(
      postId: postId,
      content: content,
      parentId: parentId,
    );
    
    if (success != null) {
      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToAuthorName = null;
      });
      SnackBarHelper.showSuccess(context, 'Комментарий добавлен');
      await _loadPosts(); 
    } else {
      SnackBarHelper.showError(context, postProvider.errorMessage ?? 'Ошибка добавления');
    }
  }

  Future<void> _deleteComment(int postId, int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        content: const Text('Это действие нельзя отменить'),
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
    
    if (confirmed == true) {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final success = await postProvider.deleteComment(postId, commentId);
      if (success) {
        SnackBarHelper.showSuccess(context, 'Комментарий удалён');
        await _loadPosts();
      } else {
        SnackBarHelper.showError(context, postProvider.errorMessage ?? 'Ошибка удаления');
      }
    }
  }
  
  /// данная функция показывает форму ответа на чей-то комментарий
  void _showReplyForm(int postId, int commentId, String authorName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToAuthorName = authorName;
    });
    _commentController.clear();
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToAuthorName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postProvider = Provider.of<PostProvider>(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Объявления',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: [
          if (widget.isTeacher && !_isCreatePostFormVisible)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreatePostForm,
              tooltip: 'Создать объявление',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: postProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : postProvider.posts.isEmpty
                ? _buildEmptyState(theme)
                : Stack(
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: postProvider.posts.length,
                        itemBuilder: (context, index) {
                          final post = postProvider.posts[index];
                          return _buildPostCard(theme, post);
                        },
                      ),
                      if (_isCreatePostFormVisible)
                        _buildCreatePostForm(theme),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 64, color: theme.colorScheme.secondary),
          const SizedBox(height: 16),
          Text(
            'Нет объявлений',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Преподаватель ещё не создал ни одного объявления',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (widget.isTeacher)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: _showCreatePostForm,
                icon: const Icon(Icons.add),
                label: const Text('Создать объявление'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreatePostForm(ThemeData theme) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Создать объявление',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _hideCreatePostForm,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPostType,
                decoration: const InputDecoration(
                  labelText: 'Тип объявления',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'announcement', child: Text('📢 Объявление')),
                  DropdownMenuItem(value: 'question', child: Text('❓ Вопрос')),
                  DropdownMenuItem(value: 'reminder', child: Text('⏰ Напоминание')),
                ],
                onChanged: (value) => setState(() => _selectedPostType = value!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _postTitleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _postContentController,
                decoration: const InputDecoration(
                  labelText: 'Содержание',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isPinned,
                    onChanged: (value) => setState(() => _isPinned = value ?? false),
                  ),
                  const Text('Закрепить объявление'),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _hideCreatePostForm,
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitPost,
                      child: const Text('Создать'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(ThemeData theme, CoursePost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPostTypeColor(post.postType),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        post.postTypeDisplay,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (post.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Закреплено',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (post.canEdit)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditPostDialog(post),
                      ),
                    if (post.canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        onPressed: () => _deletePost(post),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  post.content,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: theme.hintColor),
                    const SizedBox(width: 4),
                    Text(
                      post.authorName,
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 14, color: theme.hintColor),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(post.createdAt),
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.comment, size: 14, color: theme.hintColor),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...post.comments.map((comment) => _buildCommentWidget(comment, post.id, theme)),
                if (_replyingToCommentId == null)
                  _buildAddCommentForm(post.id, null, null, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentWidget(CoursePostComment comment, int postId, ThemeData theme, {int depth = 0}) {
    final leftPadding = depth * 20.0;
    
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: comment.authorRole == 'преподаватель'
                  ? theme.primaryColor.withOpacity(0.1)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      comment.authorRole == 'преподаватель' ? Icons.school : Icons.person,
                      size: 14,
                      color: comment.authorRole == 'преподаватель' ? Colors.green : theme.hintColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: comment.authorRole == 'преподаватель' ? Colors.green : null,
                      ),
                    ),
                    if (comment.authorRole == 'преподаватель')
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Преподаватель',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(fontSize: 10, color: theme.hintColor),
                    ),
                    if (comment.canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        onPressed: () => _deleteComment(postId, comment.id),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.content,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      if (_replyingToCommentId == comment.id) {
                        _cancelReply();
                      } else {
                        _showReplyForm(postId, comment.id, comment.authorName);
                      }
                    },
                    style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    child: Text(
                      _replyingToCommentId == comment.id ? 'Отмена' : 'Ответить',
                      style: TextStyle(fontSize: 11, color: theme.primaryColor),
                    ),
                  ),
                ),
                if (_replyingToCommentId == comment.id)
                  _buildAddCommentForm(postId, comment.id, comment.authorName, theme),
              ],
            ),
          ),
          ...comment.replies.map((reply) => _buildCommentWidget(reply, postId, theme, depth: depth + 1)),
        ],
      ),
    );
  }

  Widget _buildAddCommentForm(int postId, int? parentId, String? parentAuthorName, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: parentAuthorName != null ? 'Ответить $parentAuthorName...' : 'Написать комментарий...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _submitComment(postId, parentId: parentId, parentAuthorName: parentAuthorName),
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.send, size: 18),
          ),
        ],
      ),
    );
  }
  
  void _showEditPostDialog(CoursePost post) {
    _postTitleController.text = post.title;
    _postContentController.text = post.content;
    _selectedPostType = post.postType;
    _isPinned = post.isPinned;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать объявление'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedPostType,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: const [
                DropdownMenuItem(value: 'announcement', child: Text('Объявление')),
                DropdownMenuItem(value: 'question', child: Text('Вопрос')),
                DropdownMenuItem(value: 'reminder', child: Text('Напоминание')),
              ],
              onChanged: (v) => setState(() => _selectedPostType = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postTitleController,
              decoration: const InputDecoration(labelText: 'Заголовок'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postContentController,
              decoration: const InputDecoration(labelText: 'Содержание'),
              maxLines: 5,
            ),
            Row(
              children: [
                Checkbox(value: _isPinned, onChanged: (v) => setState(() => _isPinned = v ?? false)),
                const Text('Закрепить'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updatePost(post.id);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePost(int postId) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    await postProvider.createPost(
      courseId: widget.courseId,
      title: _postTitleController.text.trim(),
      content: _postContentController.text.trim(),
      postType: _selectedPostType,
      isPinned: _isPinned,
    );
    await _loadPosts();
    SnackBarHelper.showSuccess(context, 'Пост обновлён');
  }

  Future<void> _deletePost(CoursePost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: Text('Вы уверены, что хотите удалить "${post.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Удалить')),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _loadPosts();
      SnackBarHelper.showSuccess(context, 'Пост удалён');
    }
  }

  Color _getPostTypeColor(String postType) {
    switch (postType) {
      case 'announcement':
        return Colors.red;
      case 'question':
        return Colors.orange;
      case 'reminder':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) {
      return '${diff.inDays} дн. назад';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ч. назад';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} мин. назад';
    } else {
      return 'только что';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}