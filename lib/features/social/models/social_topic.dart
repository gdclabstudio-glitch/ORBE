class SocialTopic {
  const SocialTopic({
    required this.id,
    required this.title,
    this.description,
    this.parentTopicId,
  });

  final String id;
  final String title;
  final String? description;
  final String? parentTopicId;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'description': description,
        'parentTopicId': parentTopicId,
      };
}
