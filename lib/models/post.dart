import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isPinned;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
    this.isPinned = false,
  });

  factory Post.fromMap(Map<String, dynamic> data, String documentId) {
    return Post(
      id: documentId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Usuário',
      avatarUrl: data['avatarUrl'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPinned: data['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'avatarUrl': avatarUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPinned': isPinned,
    };
  }
}
