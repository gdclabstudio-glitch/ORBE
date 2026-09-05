import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/community/community_errors.dart';
import 'package:labomba_app/features/social/domain/community/community_pagination.dart';
import 'package:labomba_app/features/social/domain/content/community_content.dart';
import 'package:labomba_app/features/social/domain/content/community_content_repository.dart';
import 'package:labomba_app/features/social/presentation/community/community_content_ui_controller.dart';
import 'package:labomba_app/features/social/views/community_content_pages.dart';

class _FakeContentRepository implements CommunityContentRepository {
  final Map<String, List<CommunityContent>> byCommunity = {};
  final Map<String, List<Evidence>> evidenceByContent = {};
  final Map<String, List<ContentCorrection>> correctionsByContent = {};
  final Map<String, List<Source>> sourcesByCommunity = {};
  Object? listError;
  int createContentCalls = 0;
  final Completer<void> createGate = Completer<void>();

  @override
  Future<CommunityContent> createContent(
      {required CommunityContent content}) async {
    createContentCalls++;
    await createGate.future;
    byCommunity.putIfAbsent(content.communityId, () => []).insert(0, content);
    return content;
  }

  @override
  Future<CommunityContent?> getContent({required String contentId}) async {
    for (final items in byCommunity.values) {
      for (final item in items) {
        if (item.contentId == contentId) return item;
      }
    }
    return null;
  }

  @override
  Future<CommunityPage<CommunityContent>> listCommunityContent({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    if (listError != null) throw listError!;
    return CommunityPage(items: byCommunity[communityId] ?? const []);
  }

  @override
  Future<CommunityContent> updateContent(
          {required CommunityContent content}) async =>
      content;

  @override
  Future<Source> createSource(
      {required String communityId, required Source source}) async {
    sourcesByCommunity.putIfAbsent(communityId, () => []).add(source);
    return source;
  }

  @override
  Future<CommunityPage<Source>> listSources({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async =>
      CommunityPage(items: sourcesByCommunity[communityId] ?? const []);

  @override
  Future<Evidence> createEvidence({required Evidence evidence}) async {
    evidenceByContent.putIfAbsent(evidence.contentId, () => []).add(evidence);
    return evidence;
  }

  @override
  Future<CommunityPage<Evidence>> listEvidence({
    required String contentId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async =>
      CommunityPage(items: evidenceByContent[contentId] ?? const []);

  @override
  Future<ContentCorrection> createCorrection(
      {required ContentCorrection correction}) async {
    correctionsByContent
        .putIfAbsent(correction.contentId, () => [])
        .add(correction);
    return correction;
  }

  @override
  Future<CommunityPage<ContentCorrection>> listCorrections({
    required String contentId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async =>
      CommunityPage(items: correctionsByContent[contentId] ?? const []);
}

CommunityContent _content(String id, String communityId,
        {ContentType type = ContentType.fact}) =>
    CommunityContent(
      contentId: id,
      communityId: communityId,
      type: type,
      title: 'Title $id',
      body: 'Context for $id.',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  test('loads content only for the requested community', () async {
    final repository = _FakeContentRepository()
      ..byCommunity['science'] = [_content('science-1', 'science')]
      ..byCommunity['music'] = [
        _content('music-1', 'music', type: ContentType.opinion)
      ];
    final controller = CommunityContentUiController(
      repository: repository,
      userId: 'alice',
    );

    await controller.loadContents('science');

    expect(controller.contentsFor('science').single.contentId, 'science-1');
    expect(
        controller
            .contentsFor('science')
            .any((item) => item.communityId == 'music'),
        isFalse);
  });

  test('exposes loading and error state without throwing from the controller',
      () async {
    final repository = _FakeContentRepository()
      ..listError =
          const CommunityError(CommunityErrorCode.forbidden, 'denied');
    final controller =
        CommunityContentUiController(repository: repository, userId: 'alice');

    await controller.loadContents('science');

    expect(controller.contentErrorFor('science')?.code,
        CommunityErrorCode.forbidden);
    expect(controller.contentsFor('science'), isEmpty);
  });

  test('prevents duplicate content submissions', () async {
    final repository = _FakeContentRepository();
    final controller =
        CommunityContentUiController(repository: repository, userId: 'alice');

    final first = controller.createContent(
      communityId: 'science',
      type: ContentType.fact,
      title: 'A claim',
      body: 'A context',
    );
    final second = await controller.createContent(
      communityId: 'science',
      type: ContentType.fact,
      title: 'A second claim',
      body: 'A context',
    );
    repository.createGate.complete();
    final created = await first;

    expect(created, isNotNull);
    expect(second, isNull);
    expect(repository.createContentCalls, 1);
  });

  testWidgets('shows type, neutral empty relation states and authored content',
      (tester) async {
    final repository = _FakeContentRepository()
      ..byCommunity['science'] = [_content('science-1', 'science')];
    final controller =
        CommunityContentUiController(repository: repository, userId: 'alice');
    await controller.loadContents('science');

    await tester.pumpWidget(MaterialApp(
      home: CommunityContentDetailPage(
        communityId: 'science',
        content: controller.contentsFor('science').single,
        controller: controller,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FACT · afirmação factual'), findsOneWidget);
    expect(find.text('Publicado por alice'), findsOneWidget);
    expect(find.text('Este conteúdo ainda não possui evidências associadas.'),
        findsOneWidget);
    expect(find.text('Nenhuma fonte foi associada.'), findsOneWidget);
    expect(find.text('Nenhuma correção foi registrada.'), findsOneWidget);
    expect(find.text('Este conteúdo é falso.'), findsNothing);
  });

  testWidgets('shows conflicting evidence and preserves correction history',
      (tester) async {
    final content = _content('science-1', 'science');
    final repository = _FakeContentRepository()
      ..byCommunity['science'] = [content]
      ..evidenceByContent['science-1'] = [
        Evidence(
            evidenceId: 'support',
            contentId: 'science-1',
            type: EvidenceType.scientificStudy,
            description: 'Supports the observation.',
            createdBy: 'bob',
            createdAt: DateTime.utc(2026, 1, 1),
            position: EvidencePosition.supports),
        Evidence(
            evidenceId: 'challenge',
            contentId: 'science-1',
            type: EvidenceType.observation,
            description: 'Challenges the observation.',
            createdBy: 'carol',
            createdAt: DateTime.utc(2026, 1, 2),
            position: EvidencePosition.challenges),
      ]
      ..correctionsByContent['science-1'] = [
        ContentCorrection(
            correctionId: 'correction-1',
            contentId: 'science-1',
            explanation: 'Adds population context.',
            createdBy: 'dana',
            createdAt: DateTime.utc(2026, 1, 3),
            updatedAt: DateTime.utc(2026, 1, 3)),
      ];
    final controller =
        CommunityContentUiController(repository: repository, userId: 'alice');

    await tester.pumpWidget(MaterialApp(
      home: CommunityContentDetailPage(
          communityId: 'science', content: content, controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Supports the observation.'), findsOneWidget);
    expect(find.textContaining('Challenges the observation.'), findsOneWidget);
    expect(find.text('Evidências: 2'), findsOneWidget);
    expect(find.text('Correções: 1'), findsOneWidget);
    expect(find.text('Há evidências que apoiam e contestam esta afirmação.'),
        findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(find.textContaining('Adds population context.'), findsOneWidget);
  });

  testWidgets('validates empty creation fields before repository submission',
      (tester) async {
    final repository = _FakeContentRepository();
    final controller =
        CommunityContentUiController(repository: repository, userId: 'alice');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityContentCreateDialog(
            communityId: 'science', controller: controller),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar'));
    await tester.pump();

    expect(find.text('Informe título e contexto.'), findsOneWidget);
    expect(repository.createContentCalls, 0);
  });

  test('requires authenticated identity for creation', () async {
    final controller = CommunityContentUiController(
      repository: _FakeContentRepository(),
      userId: null,
    );

    await expectLater(
      controller.createContent(
        communityId: 'science',
        type: ContentType.fact,
        title: 'Title',
        body: 'Body',
      ),
      throwsA(isA<CommunityError>().having(
        (error) => error.code,
        'code',
        CommunityErrorCode.unauthorized,
      )),
    );
  });
}
