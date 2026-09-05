import 'package:flutter/foundation.dart';

import '../../domain/community/community_errors.dart';
import '../../domain/community/community_pagination.dart';
import '../../domain/content/community_content.dart';
import '../../domain/content/community_content_repository.dart';

class CommunityContentUiController extends ChangeNotifier {
  CommunityContentUiController({
    required CommunityContentRepository repository,
    required this.userId,
  }) : _repository = repository;

  final CommunityContentRepository _repository;
  final String? userId;
  final Map<String, List<CommunityContent>> _contents = {};
  final Map<String, String?> _contentCursors = {};
  final Map<String, CommunityError?> _contentErrors = {};
  final Set<String> _loadingContents = {};
  final Set<String> _loadingMoreContents = {};
  final Map<String, List<Evidence>> _evidence = {};
  final Map<String, List<ContentCorrection>> _corrections = {};
  final Map<String, List<Source>> _sources = {};
  final Map<String, CommunityError?> _relationErrors = {};
  final Set<String> _loadingRelations = {};
  final Set<String> _submitting = {};
  bool _disposed = false;

  List<CommunityContent> contentsFor(String communityId) =>
      List.unmodifiable(_contents[communityId] ?? const []);

  CommunityError? contentErrorFor(String communityId) =>
      _contentErrors[communityId];

  bool isLoadingContents(String communityId) =>
      _loadingContents.contains(communityId);

  bool isLoadingMoreContents(String communityId) =>
      _loadingMoreContents.contains(communityId);

  bool hasMoreContents(String communityId) =>
      _contentCursors[communityId] != null;

  List<Evidence> evidenceFor(String contentId) =>
      List.unmodifiable(_evidence[contentId] ?? const []);

  List<ContentCorrection> correctionsFor(String contentId) =>
      List.unmodifiable(_corrections[contentId] ?? const []);

  List<Source> sourcesFor(String communityId) =>
      List.unmodifiable(_sources[communityId] ?? const []);

  CommunityError? relationErrorFor(String contentId) =>
      _relationErrors[contentId];

  bool isLoadingRelations(String contentId) =>
      _loadingRelations.contains(contentId);

  bool isSubmitting(String operation) => _submitting.contains(operation);

  Future<void> loadContents(String communityId, {bool refresh = true}) async {
    if (_loadingContents.contains(communityId) ||
        _loadingMoreContents.contains(communityId)) return;
    if (refresh) {
      _contents[communityId] = [];
      _contentCursors[communityId] = null;
    }
    _loadingContents.add(communityId);
    _contentErrors.remove(communityId);
    _notify();
    try {
      final page = await _repository.listCommunityContent(
        communityId: communityId,
        page: CommunityPageRequest(cursor: _contentCursors[communityId]),
      );
      _contents[communityId] = [
        ...(_contents[communityId] ?? const []),
        ...page.items,
      ];
      _contentCursors[communityId] = page.nextCursor;
    } catch (error) {
      _contentErrors[communityId] = _asError(error);
    } finally {
      _loadingContents.remove(communityId);
      _notify();
    }
  }

  Future<void> loadMoreContents(String communityId) async {
    if (_loadingContents.contains(communityId) ||
        _loadingMoreContents.contains(communityId) ||
        !hasMoreContents(communityId)) return;
    _loadingMoreContents.add(communityId);
    _contentErrors.remove(communityId);
    _notify();
    try {
      final page = await _repository.listCommunityContent(
        communityId: communityId,
        page: CommunityPageRequest(cursor: _contentCursors[communityId]),
      );
      _contents[communityId] = [
        ...(_contents[communityId] ?? const []),
        ...page.items,
      ];
      _contentCursors[communityId] = page.nextCursor;
    } catch (error) {
      _contentErrors[communityId] = _asError(error);
    } finally {
      _loadingMoreContents.remove(communityId);
      _notify();
    }
  }

  Future<void> loadRelations({
    required String communityId,
    required String contentId,
  }) async {
    if (_loadingRelations.contains(contentId)) return;
    _loadingRelations.add(contentId);
    _relationErrors.remove(contentId);
    _notify();
    try {
      final results = await Future.wait([
        _repository.listEvidence(contentId: contentId),
        _repository.listCorrections(contentId: contentId),
        _repository.listSources(communityId: communityId),
      ]);
      _evidence[contentId] = (results[0] as CommunityPage<Evidence>).items;
      _corrections[contentId] =
          (results[1] as CommunityPage<ContentCorrection>).items;
      _sources[communityId] = (results[2] as CommunityPage<Source>).items;
    } catch (error) {
      _relationErrors[contentId] = _asError(error);
    } finally {
      _loadingRelations.remove(contentId);
      _notify();
    }
  }

  Future<CommunityContent?> createContent({
    required String communityId,
    required ContentType type,
    required String title,
    required String body,
  }) async {
    final authorId = _requireUser();
    final operation = 'create-content';
    if (!_submitting.add(operation)) return null;
    _notify();
    try {
      final content = CommunityContent(
        contentId: _newId('content'),
        communityId: communityId,
        type: type,
        title: title.trim(),
        body: body.trim(),
        createdBy: authorId,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      final created = await _repository.createContent(content: content);
      _contents.update(communityId, (items) => [created, ...items],
          ifAbsent: () => [created]);
      return created;
    } finally {
      _submitting.remove(operation);
      _notify();
    }
  }

  Future<Evidence?> createEvidence({
    required String contentId,
    required EvidenceType type,
    required String description,
    String? sourceId,
    EvidencePosition position = EvidencePosition.contextualizes,
  }) async {
    final authorId = _requireUser();
    final operation = 'evidence:$contentId';
    if (!_submitting.add(operation)) return null;
    _notify();
    try {
      final created = await _repository.createEvidence(
        evidence: Evidence(
          evidenceId: _newId('evidence'),
          contentId: contentId,
          type: type,
          description: description.trim(),
          sourceId: sourceId,
          position: position,
          createdBy: authorId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      _evidence.update(contentId, (items) => [...items, created],
          ifAbsent: () => [created]);
      return created;
    } finally {
      _submitting.remove(operation);
      _notify();
    }
  }

  Future<Source?> createSource({
    required String communityId,
    required SourceType type,
    required String title,
    required String locator,
    String? author,
    String? publisher,
  }) async {
    final authorId = _requireUser();
    final operation = 'source:$communityId';
    if (!_submitting.add(operation)) return null;
    _notify();
    try {
      final created = await _repository.createSource(
        communityId: communityId,
        source: Source(
          sourceId: _newId('source'),
          type: type,
          title: title.trim(),
          locator: locator.trim(),
          author: author?.trim(),
          publisher: publisher?.trim(),
          createdBy: authorId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      _sources.update(communityId, (items) => [...items, created],
          ifAbsent: () => [created]);
      return created;
    } finally {
      _submitting.remove(operation);
      _notify();
    }
  }

  Future<ContentCorrection?> createCorrection({
    required String contentId,
    required String explanation,
    String? proposedBody,
  }) async {
    final authorId = _requireUser();
    final operation = 'correction:$contentId';
    if (!_submitting.add(operation)) return null;
    _notify();
    try {
      final now = DateTime.now().toUtc();
      final created = await _repository.createCorrection(
        correction: ContentCorrection(
          correctionId: _newId('correction'),
          contentId: contentId,
          explanation: explanation.trim(),
          proposedBody: proposedBody?.trim(),
          createdBy: authorId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      _corrections.update(contentId, (items) => [...items, created],
          ifAbsent: () => [created]);
      return created;
    } finally {
      _submitting.remove(operation);
      _notify();
    }
  }

  String _requireUser() {
    final value = userId?.trim();
    if (value == null || value.isEmpty) {
      throw const CommunityError(
        CommunityErrorCode.unauthorized,
        'Authentication required',
      );
    }
    return value;
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  CommunityError _asError(Object error) => error is CommunityError
      ? error
      : const CommunityError(
          CommunityErrorCode.unknown,
          'Unexpected community content error',
        );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
