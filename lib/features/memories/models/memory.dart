import 'package:flutter/foundation.dart';

/// Domain model for a Memory (a user-saved memory / note with optional images)
@immutable
class Memory {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final List<String> imageUrls;
  final DateTime createdAt;
  final String? ownerId;

  Memory({
    required this.id,
    required this.title,
    this.description,
    DateTime? date,
    this.imageUrls = const [],
    DateTime? createdAt,
    this.ownerId,
  })  : date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Memory copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    List<String>? imageUrls,
    DateTime? createdAt,
    String? ownerId,
  }) {
    return Memory(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'imageUrls': imageUrls,
        'createdAt': createdAt.toIso8601String(),
        'ownerId': ownerId,
      };

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        date: DateTime.parse(json['date'] as String),
        imageUrls:
            (json['imageUrls'] as List<dynamic>?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        ownerId: json['ownerId'] as String?,
      );
}
