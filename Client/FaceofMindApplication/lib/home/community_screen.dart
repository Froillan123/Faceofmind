import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dart:async';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<dynamic>> _postsFuture;
  String? _token;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchPosts();
  }

  Future<void> _loadTokenAndFetchPosts() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _currentUserId = prefs.getInt('user_id');
    setState(() {
      _postsFuture = ApiService.fetchPosts(_token ?? '');
    });
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _postsFuture = ApiService.fetchPosts(_token ?? '');
    });
  }

  void _showCommentsModal(BuildContext context, dynamic post) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CommentsModal(
        post: post,
        token: _token ?? '',
      ),
    );
  }

  void _showCreatePostModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CreatePostModal(
        token: _token ?? '',
        onPostCreated: _refreshPosts,
      ),
    );
  }

  Color get mainColor => const Color(0xFF5CD581);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: mainColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Posts',
            onPressed: _refreshPosts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: FutureBuilder<List<dynamic>>(
          future: _postsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading posts: \\${snapshot.error}'));
            }
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return const Center(child: Text('No posts yet. Be the first to post!'));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final post = posts[i];
                final initials = _getInitials(post['user_id']);
                final createdAt = DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.grey[50],
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _showCommentsModal(context, post),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: mainColor.withOpacity(0.15),
                                child: Text(initials, style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Text(_formatTimeAgo(createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              const Spacer(),
                              if (_currentUserId != null && post['user_id'] == _currentUserId)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      final newContent = await showDialog<String>(
                                        context: context,
                                        builder: (context) => _EditDialog(initialValue: post['content'] ?? ''),
                                      );
                                      if (newContent != null && newContent.trim().isNotEmpty) {
                                        await ApiService.editPost(_token ?? '', post['id'], newContent.trim());
                                        _refreshPosts();
                                      }
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Post'),
                                          content: const Text('Are you sure you want to delete this post?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ApiService.deletePost(_token ?? '', post['id']);
                                        _refreshPosts();
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(post['content'] ?? '', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.comment, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${post['comment_count'] ?? 0} comments',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePostModal(context),
        backgroundColor: mainColor,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Post',
      ),
    );
  }

  String _getInitials(dynamic userId) {
    // Placeholder: just use userId for now, or fetch user info if available
    return userId != null ? userId.toString().substring(0, 1) : '?';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }
}

class CommentsModal extends StatefulWidget {
  final dynamic post;
  final String token;
  const CommentsModal({super.key, required this.post, required this.token});

  @override
  State<CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  late Future<List<dynamic>> _commentsFuture;
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserAndFetchComments();
  }

  Future<void> _loadUserAndFetchComments() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');
    _fetchComments();
  }

  void _fetchComments() {
    setState(() {
      _commentsFuture = ApiService.fetchComments(widget.token, widget.post['id']);
    });
  }

  Future<void> _submitComment() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() => _submitting = true);
    final res = await ApiService.addComment(widget.token, widget.post['id'], content);
    if (res['success'] == true) {
      _controller.clear();
      _fetchComments();
    }
    setState(() => _submitting = false);
  }

  Color get mainColor => const Color(0xFF5CD581);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Comments',
                  onPressed: _fetchComments,
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _commentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(child: Text('No comments yet.'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: comments.length,
                    itemBuilder: (context, i) {
                      final comment = comments[i];
                      final initials = comment['user_id'] != null ? comment['user_id'].toString().substring(0, 1) : '?';
                      final createdAt = DateTime.tryParse(comment['created_at'] ?? '') ?? DateTime.now();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: mainColor.withOpacity(0.15),
                          child: Text(initials, style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(comment['content'] ?? ''),
                        subtitle: Text(_formatTimeAgo(createdAt), style: const TextStyle(fontSize: 12)),
                        trailing: (_currentUserId != null && comment['user_id'] == _currentUserId)
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    final newContent = await showDialog<String>(
                                      context: context,
                                      builder: (context) => _EditDialog(initialValue: comment['content'] ?? ''),
                                    );
                                    if (newContent != null && newContent.trim().isNotEmpty) {
                                      await ApiService.editComment(widget.token, widget.post['id'], comment['id'], newContent.trim());
                                      _fetchComments();
                                    }
                                  } else if (value == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Comment'),
                                        content: const Text('Are you sure you want to delete this comment?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ApiService.deleteComment(widget.token, widget.post['id'], comment['id']);
                                      _fetchComments();
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _submitting
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: Icon(Icons.send, color: mainColor),
                          onPressed: _submitComment,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }
}

class CreatePostModal extends StatefulWidget {
  final String token;
  final VoidCallback onPostCreated;
  const CreatePostModal({super.key, required this.token, required this.onPostCreated});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  Color get mainColor => const Color(0xFF5CD581);

  Future<void> _submitPost() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await ApiService.createPost(widget.token, content);
    if (res['success'] == true) {
      widget.onPostCreated();
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = res['message'] ?? 'Failed to create post.';
      });
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                minLines: 3,
                maxLines: 6,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  onPressed: _submitting ? null : _submitPost,
                  child: _submitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Post'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditDialog extends StatelessWidget {
  final String initialValue;
  const _EditDialog({super.key, required this.initialValue});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialValue);
    return AlertDialog(
      title: const Text('Edit'),
      content: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 6,
        decoration: const InputDecoration(hintText: 'Edit content'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
      ],
    );
  }
} 