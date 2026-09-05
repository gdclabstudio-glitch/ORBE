enum OrbMembershipKind {
  relationship,
  membership,
  relevance,
  topic,
  participation,
  context,
  unknown,
}

class OrbMembership {
  const OrbMembership({
    required this.orbId,
    required this.contextId,
    this.kind = OrbMembershipKind.unknown,
    this.label,
    this.relevance = 0,
  });

  final String orbId;
  final String contextId;
  final OrbMembershipKind kind;
  final String? label;
  final double relevance;

  Map<String, Object?> toMap() => <String, Object?>{
        'orbId': orbId,
        'contextId': contextId,
        'kind': kind.name,
        'label': label,
        'relevance': relevance,
      };
}
