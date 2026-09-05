import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/community/community_errors.dart';
import 'package:labomba_app/features/social/domain/content/community_content.dart';
import 'package:labomba_app/features/social/infrastructure/firestore_community_content_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreCommunityContentRepository repository;
  final createdAt = DateTime.utc(2026, 1, 1);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreCommunityContentRepository(firestore: firestore);
  });

  CommunityContent content({String id = 'content-1'}) => CommunityContent(
        contentId: id,
        communityId: 'science',
        type: ContentType.fact,
        title: 'Observed association',
        body: 'Study X observed an association in population Y.',
        createdBy: 'alice',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

  test('persists and reads content with a stable document identity', () async {
    final created = await repository.createContent(content: content());
    final restored = await repository.getContent(contentId: 'content-1');

    expect(created.contentId, 'content-1');
    expect(restored?.communityId, 'science');
    expect(restored?.type, ContentType.fact);
    expect(restored?.createdBy, 'alice');
  });

  test('updates only the editable content fields', () async {
    await repository.createContent(content: content());
    final updated = await repository.updateContent(
      content: CommunityContent(
        contentId: 'content-1',
        communityId: 'science',
        type: ContentType.interpretation,
        title: 'Updated context',
        body: 'The context is now explicit.',
        createdBy: 'alice',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    expect(updated.type, ContentType.interpretation);
    expect(updated.title, 'Updated context');
    expect(updated.createdBy, 'alice');
    expect(updated.communityId, 'science');
  });

  test('persists source, evidence, and correction relations', () async {
    await repository.createContent(content: content());
    final source = await repository.createSource(
      communityId: 'science',
      source: Source(
        sourceId: 'source-1',
        type: SourceType.scientificArticle,
        title: 'Study X',
        locator: 'https://example.org/study-x',
        createdBy: 'bob',
        createdAt: createdAt,
      ),
    );
    final evidence = await repository.createEvidence(
      evidence: Evidence(
        evidenceId: 'evidence-1',
        contentId: 'content-1',
        type: EvidenceType.scientificStudy,
        description: 'The study reports the association.',
        sourceId: source.sourceId,
        createdBy: 'bob',
        createdAt: createdAt,
      ),
    );
    final correction = await repository.createCorrection(
      correction: ContentCorrection(
        correctionId: 'correction-1',
        contentId: 'content-1',
        explanation: 'The population context was missing.',
        createdBy: 'carol',
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    expect(evidence.contentId, 'content-1');
    expect(correction.contentId, 'content-1');
    expect(
      (await repository.listEvidence(contentId: 'content-1'))
          .items
          .single
          .evidenceId,
      'evidence-1',
    );
    expect(
      (await repository.listCorrections(contentId: 'content-1'))
          .items
          .single
          .correctionId,
      'correction-1',
    );
  });

  test('rejects invalid IDs before touching Firestore', () async {
    expect(
      () => repository.getContent(contentId: ' '),
      throwsA(isA<CommunityError>().having(
        (error) => error.code,
        'code',
        CommunityErrorCode.invalidRequest,
      )),
    );
    expect(
      () => repository.listSources(communityId: ' '),
      throwsA(isA<CommunityError>().having(
        (error) => error.code,
        'code',
        CommunityErrorCode.invalidCommunity,
      )),
    );
  });
}
