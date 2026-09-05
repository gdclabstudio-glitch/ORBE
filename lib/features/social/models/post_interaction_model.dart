import 'package:flutter/foundation.dart';

/// Models for post interactions: comments, reactions and moderation metadata.
///
/// Designed as lightweight immutable data classes with JSON (de)serialization
/// helpers to persist in Firestore or local storage.

@immutable
class Reaction {
  final String id; // unique id for the reaction event
  final String userId;
  final String type; // e.g., 'like', 'love', 'laugh', 'sad', 'angry'
  final DateTime createdAt;

  const Reaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.createdAt,
  });

  Reaction copyWith({
    String? id,
    String? userId,
    String? type,
    DateTime? createdAt,
  }) {
    return Reaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Reaction.fromJson(Map<String, dynamic> json) => Reaction(
        id: json['id'] as String,
        userId: json['userId'] as String,
        type: json['type'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

@immutable
class Comment {
  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;
  final bool deleted; // soft-delete flag for moderation

  const Comment({
    required this.id,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.deleted = false,
  });

  Comment copyWith({
    String? id,
    String? authorId,
    String? text,
    DateTime? createdAt,
    bool? deleted,
  }) {
    return Comment(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'deleted': deleted,
      };

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        authorId: json['authorId'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        deleted: json['deleted'] as bool? ?? false,
      );
}

@immutable
class PostInteraction {
  final String postId;
  final List<Comment> comments;
  final List<Reaction> reactions;

  PostInteraction({
    required this.postId,
    List<Comment>? comments,
    List<Reaction>? reactions,
  })  : comments = List.unmodifiable(comments ?? const []),
        reactions = List.unmodifiable(reactions ?? const []);

  PostInteraction copyWith({
    String? postId,
    List<Comment>? comments,
    List<Reaction>? reactions,
  }) {
    return PostInteraction(
      postId: postId ?? this.postId,
      comments: comments ?? this.comments,
      reactions: reactions ?? this.reactions,
    );
  }

  /// Add a comment
  PostInteraction addComment(Comment c) {
    final updated = List<Comment>.from(comments)..add(c);
    return copyWith(comments: updated);
  }

  /// Soft-delete a comment by id (keeps history for moderation/audit)
  PostInteraction deleteComment(String commentId) {
    final updated = comments
        .map((c) => c.id == commentId ? c.copyWith(deleted: true) : c)
        .toList();
    return copyWith(comments: updated);
  }

  /// Add or replace a reaction (unique per user+type semantics left to callers)
  PostInteraction addReaction(Reaction r) {
    final updated = List<Reaction>.from(reactions)
      ..removeWhere((ex) => ex.id == r.id)
      ..add(r);
    return copyWith(reactions: updated);
  }

  /// Remove reaction by id
  PostInteraction removeReaction(String reactionId) {
    final updated = reactions.where((r) => r.id != reactionId).toList();
    return copyWith(reactions: updated);
  }

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'comments': comments.map((c) => c.toJson()).toList(),
        'reactions': reactions.map((r) => r.toJson()).toList(),
      };

  factory PostInteraction.fromJson(Map<String, dynamic> json) =>
      PostInteraction(
        postId: json['postId'] as String,
        comments: (json['comments'] as List<dynamic>?)
            ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactions: (json['reactions'] as List<dynamic>?)
            ?.map((e) => Reaction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Convenience: return number of non-deleted comments
  int get activeCommentsCount => comments.where((c) => !c.deleted).length;

  /// Group reactions by type with counts
  Map<String, int> reactionsSummary() {
    final Map<String, int> summary = {};
    for (final r in reactions) {
      summary[r.type] = (summary[r.type] ?? 0) + 1;
    }
    return summary;
  }

  @override
  String toString() =>
      'PostInteraction(postId: $postId, comments: ${comments.length}, reactions: ${reactions.length})';
}
