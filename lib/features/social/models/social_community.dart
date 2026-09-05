import 'social_topic.dart';

class SocialCommunity {
  const SocialCommunity({
    required this.id,
    required this.name,
    this.description,
    this.topic,
  });

  final String id;
  final String name;
  final String? description;
  final SocialTopic? topic;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'description': description,
        'topic': topic?.toMap(),
      };
}
