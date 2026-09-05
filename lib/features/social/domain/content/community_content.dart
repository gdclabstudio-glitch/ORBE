enum ContentType {
  fact,
  opinion,
  hypothesis,
  discussion,
  question,
  interpretation,
}

enum CommunityContentLifecycle {
  active,
  underReview,
  restricted,
  corrected,
  archived,
}

enum EvidenceType {
  scientificStudy,
  book,
  institutionalDocument,
  historicalSource,
  officialWebsite,
  interview,
  publicDocument,
  observation,
  other,
}

enum EvidencePosition {
  supports,
  challenges,
  contextualizes,
}

enum SourceType {
  scientificArticle,
  book,
  institutionalDocument,
  historicalSource,
  officialWebsite,
  interview,
  publicDocument,
  other,
}

class CommunityContent {
  CommunityContent({
    required this.contentId,
    required this.communityId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lifecycle = CommunityContentLifecycle.active,
  }) {
    _validate();
  }

  final String contentId;
  final String communityId;
  final ContentType type;
  final String title;
  final String body;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CommunityContentLifecycle lifecycle;

  Map<String, Object?> toMap() => {
        'contentId': contentId,
        'communityId': communityId,
        'type': type.name,
        'title': title,
        'body': body,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'lifecycle': lifecycle.name,
      };

  factory CommunityContent.fromMap(Map<String, dynamic> map) {
    return CommunityContent(
      contentId: _requiredString(map['contentId'], 'contentId'),
      communityId: _requiredString(map['communityId'], 'communityId'),
      type: _enumValue(ContentType.values, map['type'], 'type'),
      title: _requiredString(map['title'], 'title'),
      body: _requiredString(map['body'], 'body'),
      createdBy: _requiredString(map['createdBy'], 'createdBy'),
      createdAt: _dateTime(map['createdAt'], 'createdAt'),
      updatedAt: _dateTime(map['updatedAt'], 'updatedAt'),
      lifecycle: map['lifecycle'] == null
          ? CommunityContentLifecycle.active
          : _enumValue(
              CommunityContentLifecycle.values, map['lifecycle'], 'lifecycle'),
    );
  }

  void _validate() {
    _requireText(contentId, 'contentId');
    _requireText(communityId, 'communityId');
    _requireText(title, 'title');
    _requireText(body, 'body');
    _requireText(createdBy, 'createdBy');
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Cannot be earlier than createdAt',
      );
    }
  }
}

class Source {
  Source({
    required this.sourceId,
    required this.type,
    required this.title,
    required this.locator,
    required this.createdBy,
    required this.createdAt,
    this.author,
    this.publisher,
  }) {
    _requireText(sourceId, 'sourceId');
    _requireText(title, 'title');
    _requireText(locator, 'locator');
    _requireText(createdBy, 'createdBy');
  }

  final String sourceId;
  final SourceType type;
  final String title;
  final String locator;
  final String? author;
  final String? publisher;
  final String createdBy;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'sourceId': sourceId,
        'type': type.name,
        'title': title,
        'locator': locator,
        'author': author,
        'publisher': publisher,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory Source.fromMap(Map<String, dynamic> map) {
    return Source(
      sourceId: _requiredString(map['sourceId'], 'sourceId'),
      type: _enumValue(SourceType.values, map['type'], 'type'),
      title: _requiredString(map['title'], 'title'),
      locator: _requiredString(map['locator'], 'locator'),
      author: _optionalString(map['author']),
      publisher: _optionalString(map['publisher']),
      createdBy: _requiredString(map['createdBy'], 'createdBy'),
      createdAt: _dateTime(map['createdAt'], 'createdAt'),
    );
  }
}

class Evidence {
  Evidence({
    required this.evidenceId,
    String? contentId,
    String? claimId,
    required this.type,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.sourceId,
    this.position = EvidencePosition.contextualizes,
  }) : contentId = contentId ?? claimId ?? '' {
    _requireText(evidenceId, 'evidenceId');
    _requireText(this.contentId, 'contentId');
    _requireText(description, 'description');
    _requireText(createdBy, 'createdBy');
    if (sourceId != null) _requireText(sourceId!, 'sourceId');
  }

  final String evidenceId;
  final String contentId;
  String get claimId => contentId;
  final EvidenceType type;
  final String description;
  final String? sourceId;
  final String createdBy;
  final DateTime createdAt;
  final EvidencePosition position;

  Map<String, Object?> toMap() => {
        'evidenceId': evidenceId,
        'contentId': contentId,
        'type': type.name,
        'description': description,
        if (sourceId != null) 'sourceId': sourceId,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'position': position.name,
      };

  factory Evidence.fromMap(Map<String, dynamic> map) {
    return Evidence(
      evidenceId: _requiredString(map['evidenceId'], 'evidenceId'),
      contentId:
          _requiredString(map['contentId'] ?? map['claimId'], 'contentId'),
      type: _enumValue(EvidenceType.values, map['type'], 'type'),
      description: _requiredString(map['description'], 'description'),
      sourceId: _optionalString(map['sourceId']),
      createdBy: _requiredString(map['createdBy'], 'createdBy'),
      createdAt: _dateTime(map['createdAt'], 'createdAt'),
      position: map['position'] == null
          ? EvidencePosition.contextualizes
          : _enumValue(EvidencePosition.values, map['position'], 'position'),
    );
  }
}

class ContentCorrection {
  ContentCorrection({
    required this.correctionId,
    required this.contentId,
    required this.explanation,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.proposedBody,
  }) {
    _requireText(correctionId, 'correctionId');
    _requireText(contentId, 'contentId');
    _requireText(explanation, 'explanation');
    _requireText(createdBy, 'createdBy');
    if (proposedBody != null) _requireText(proposedBody!, 'proposedBody');
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Cannot be earlier than createdAt',
      );
    }
  }

  final String correctionId;
  final String contentId;
  final String explanation;
  final String? proposedBody;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'correctionId': correctionId,
        'contentId': contentId,
        'explanation': explanation,
        'proposedBody': proposedBody,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory ContentCorrection.fromMap(Map<String, dynamic> map) {
    return ContentCorrection(
      correctionId: _requiredString(map['correctionId'], 'correctionId'),
      contentId: _requiredString(map['contentId'], 'contentId'),
      explanation: _requiredString(map['explanation'], 'explanation'),
      proposedBody: _optionalString(map['proposedBody']),
      createdBy: _requiredString(map['createdBy'], 'createdBy'),
      createdAt: _dateTime(map['createdAt'], 'createdAt'),
      updatedAt: _dateTime(map['updatedAt'], 'updatedAt'),
    );
  }
}

void _requireText(String value, String field) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, field, 'Cannot be empty');
  }
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('Missing or invalid $field');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  return _requiredString(value, 'value');
}

T _enumValue<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is String) {
    for (final item in values) {
      if (item.name == value) return item;
    }
  }
  throw FormatException('Missing or invalid $field');
}

DateTime _dateTime(Object? value, String field) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  throw FormatException('Missing or invalid $field');
}
