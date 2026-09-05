import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/content/community_content.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1);
  final updatedAt = DateTime.utc(2026, 1, 2);

  test('creates a typed authored content item', () {
    final content = CommunityContent(
      contentId: 'claim-1',
      communityId: 'science',
      type: ContentType.fact,
      title: 'Observed association',
      body: 'Study X observed an association in population Y.',
      createdBy: 'alice',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(content.type, ContentType.fact);
    expect(content.createdBy, 'alice');
    expect(content.toMap()['type'], 'fact');
  });

  test('rejects empty identity and invalid timestamp ordering', () {
    expect(
      () => CommunityContent(
        contentId: '',
        communityId: 'science',
        type: ContentType.opinion,
        title: 'Title',
        body: 'Body',
        createdBy: 'alice',
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => CommunityContent(
        contentId: 'content-1',
        communityId: 'science',
        type: ContentType.hypothesis,
        title: 'Title',
        body: 'Body',
        createdBy: 'alice',
        createdAt: updatedAt,
        updatedAt: createdAt,
      ),
      throwsArgumentError,
    );
  });

  test('round trips content without Firebase types', () {
    final content = CommunityContent(
      contentId: 'content-1',
      communityId: 'music',
      type: ContentType.interpretation,
      title: 'Meaning',
      body: 'A contextual interpretation.',
      createdBy: 'bob',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final restored = CommunityContent.fromMap(content.toMap());

    expect(restored.contentId, content.contentId);
    expect(restored.type, ContentType.interpretation);
    expect(restored.createdAt, createdAt);
  });

  test('requires authored, related evidence and valid source', () {
    final source = Source(
      sourceId: 'source-1',
      type: SourceType.scientificArticle,
      title: 'Study X',
      locator: 'https://example.org/study-x',
      createdBy: 'bob',
      createdAt: createdAt,
    );
    final evidence = Evidence(
      evidenceId: 'evidence-1',
      claimId: 'claim-1',
      type: EvidenceType.scientificStudy,
      description: 'The study reports the observed association.',
      sourceId: source.sourceId,
      createdBy: 'bob',
      createdAt: createdAt,
    );

    expect(Source.fromMap(source.toMap()).type, SourceType.scientificArticle);
    expect(Evidence.fromMap(evidence.toMap()).claimId, 'claim-1');
    expect(
      () => Source(
        sourceId: 'source-2',
        type: SourceType.book,
        title: 'Book',
        locator: '',
        createdBy: 'bob',
        createdAt: createdAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => Evidence(
        evidenceId: 'evidence-2',
        claimId: '',
        type: EvidenceType.other,
        description: 'Description',
        createdBy: 'bob',
        createdAt: createdAt,
      ),
      throwsArgumentError,
    );
  });

  test('preserves original content identity when recording a correction', () {
    final correction = ContentCorrection(
      correctionId: 'correction-1',
      contentId: 'claim-1',
      explanation: 'The original wording omitted the population context.',
      proposedBody: 'Study X observed an association in population Y.',
      createdBy: 'carol',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final restored = ContentCorrection.fromMap(correction.toMap());

    expect(restored.contentId, 'claim-1');
    expect(restored.createdBy, 'carol');
    expect(restored.proposedBody, contains('population'));
  });
}
