import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Source;

import '../domain/community/community_errors.dart';
import '../domain/community/community_pagination.dart';
import '../domain/content/community_content.dart';
import '../domain/content/community_content_repository.dart';

class FirestoreCommunityContentRepository
    implements CommunityContentRepository {
  FirestoreCommunityContentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _contents = 'community_contents';
  static const _communities = 'communities';
  static const _sources = 'sources';
  static const _evidences = 'evidences';
  static const _corrections = 'content_corrections';

  final FirebaseFirestore _firestore;

  @override
  Future<CommunityContent> createContent({
    required CommunityContent content,
  }) async {
    _requireId(content.contentId, CommunityErrorCode.invalidRequest);
    _requireId(content.communityId, CommunityErrorCode.invalidCommunity);
    try {
      final reference = _firestore.collection(_contents).doc(content.contentId);
      final data = _withServerContentCreateTimestamps(content.toMap());
      await reference.set(data);
      final created = await reference.get();
      return _content(created);
    } catch (error) {
      throw _mapError(error, 'Unable to create community content');
    }
  }

  @override
  Future<CommunityContent?> getContent({required String contentId}) async {
    _requireId(contentId, CommunityErrorCode.invalidRequest);
    try {
      final snapshot =
          await _firestore.collection(_contents).doc(contentId).get();
      return snapshot.exists ? _content(snapshot) : null;
    } catch (error) {
      throw _mapError(error, 'Unable to read community content');
    }
  }

  @override
  Future<CommunityPage<CommunityContent>> listCommunityContent({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    _requireId(communityId, CommunityErrorCode.invalidCommunity);
    try {
      final query = await _pageQuery(
        _firestore
            .collection(_contents)
            .where('communityId', isEqualTo: communityId.trim())
            .orderBy('createdAt', descending: true),
        page,
        _contents,
      );
      final snapshots = await query.limit(page.limit + 1).get();
      return CommunityPage(
        items: snapshots.docs
            .take(page.limit)
            .map(_content)
            .toList(growable: false),
        nextCursor: snapshots.docs.length > page.limit
            ? _encodeCursor(snapshots.docs[page.limit - 1].id)
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list community content');
    }
  }

  @override
  Future<CommunityContent> updateContent({
    required CommunityContent content,
  }) async {
    _requireId(content.contentId, CommunityErrorCode.invalidRequest);
    try {
      final reference = _firestore.collection(_contents).doc(content.contentId);
      await reference.update({
        'type': content.type.name,
        'title': content.title,
        'body': content.body,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final updated = await reference.get();
      return _content(updated);
    } catch (error) {
      throw _mapError(error, 'Unable to update community content');
    }
  }

  @override
  Future<Source> createSource({
    required String communityId,
    required Source source,
  }) async {
    _requireId(communityId, CommunityErrorCode.invalidCommunity);
    try {
      final reference = _sourceReference(communityId, source.sourceId);
      await reference.set(_withServerCreateTimestamps(source.toMap()));
      return _source(await reference.get());
    } catch (error) {
      throw _mapError(error, 'Unable to create source');
    }
  }

  @override
  Future<CommunityPage<Source>> listSources({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    _requireId(communityId, CommunityErrorCode.invalidCommunity);
    try {
      final path = _sourceCollection(communityId);
      final query = await _pageQuery(
        path.orderBy('createdAt', descending: true),
        page,
        path.path,
      );
      final snapshots = await query.limit(page.limit + 1).get();
      return CommunityPage(
        items: snapshots.docs
            .take(page.limit)
            .map(_source)
            .toList(growable: false),
        nextCursor: snapshots.docs.length > page.limit
            ? _encodeCursor(snapshots.docs[page.limit - 1].id)
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list sources');
    }
  }

  @override
  Future<Evidence> createEvidence({required Evidence evidence}) async {
    _requireId(evidence.contentId, CommunityErrorCode.invalidRequest);
    try {
      final reference = _evidenceReference(
        evidence.contentId,
        evidence.evidenceId,
      );
      await reference.set(_withServerCreateTimestamps(evidence.toMap()));
      return _evidence(await reference.get());
    } catch (error) {
      throw _mapError(error, 'Unable to create evidence');
    }
  }

  @override
  Future<CommunityPage<Evidence>> listEvidence({
    required String contentId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    _requireId(contentId, CommunityErrorCode.invalidRequest);
    try {
      final path = _evidenceCollection(contentId);
      final query = await _pageQuery(
        path.orderBy('createdAt', descending: true),
        page,
        path.path,
      );
      final snapshots = await query.limit(page.limit + 1).get();
      return CommunityPage(
        items: snapshots.docs
            .take(page.limit)
            .map(_evidence)
            .toList(growable: false),
        nextCursor: snapshots.docs.length > page.limit
            ? _encodeCursor(snapshots.docs[page.limit - 1].id)
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list evidence');
    }
  }

  @override
  Future<ContentCorrection> createCorrection({
    required ContentCorrection correction,
  }) async {
    _requireId(correction.contentId, CommunityErrorCode.invalidRequest);
    try {
      final reference = _correctionReference(
        correction.contentId,
        correction.correctionId,
      );
      await reference
          .set(_withServerCorrectionCreateTimestamps(correction.toMap()));
      return _correction(await reference.get());
    } catch (error) {
      throw _mapError(error, 'Unable to create correction');
    }
  }

  @override
  Future<CommunityPage<ContentCorrection>> listCorrections({
    required String contentId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    _requireId(contentId, CommunityErrorCode.invalidRequest);
    try {
      final path = _correctionCollection(contentId);
      final query = await _pageQuery(
        path.orderBy('createdAt', descending: true),
        page,
        path.path,
      );
      final snapshots = await query.limit(page.limit + 1).get();
      return CommunityPage(
        items: snapshots.docs
            .take(page.limit)
            .map(_correction)
            .toList(growable: false),
        nextCursor: snapshots.docs.length > page.limit
            ? _encodeCursor(snapshots.docs[page.limit - 1].id)
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list corrections');
    }
  }

  CollectionReference<Map<String, dynamic>> _sourceCollection(
          String communityId) =>
      _firestore
          .collection(_communities)
          .doc(communityId.trim())
          .collection(_sources);

  DocumentReference<Map<String, dynamic>> _sourceReference(
          String communityId, String sourceId) =>
      _sourceCollection(communityId).doc(sourceId);

  CollectionReference<Map<String, dynamic>> _evidenceCollection(
          String contentId) =>
      _firestore
          .collection(_contents)
          .doc(contentId.trim())
          .collection(_evidences);

  DocumentReference<Map<String, dynamic>> _evidenceReference(
          String contentId, String evidenceId) =>
      _evidenceCollection(contentId).doc(evidenceId);

  CollectionReference<Map<String, dynamic>> _correctionCollection(
          String contentId) =>
      _firestore
          .collection(_contents)
          .doc(contentId.trim())
          .collection(_corrections);

  DocumentReference<Map<String, dynamic>> _correctionReference(
          String contentId, String correctionId) =>
      _correctionCollection(contentId).doc(correctionId);

  Future<Query<Map<String, dynamic>>> _pageQuery(
    Query<Map<String, dynamic>> query,
    CommunityPageRequest page,
    String collection,
  ) async {
    if (page.cursor == null) return query;
    final snapshot = await _firestore
        .doc('$collection/${_decodeCursor(page.cursor!)}')
        .get();
    if (!snapshot.exists) {
      throw const CommunityError(
          CommunityErrorCode.invalidRequest, 'Invalid cursor');
    }
    return query.startAfterDocument(snapshot);
  }

  Map<String, Object?> _withServerCreateTimestamps(Map<String, Object?> data) =>
      {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, Object?> _withServerContentCreateTimestamps(
          Map<String, Object?> data) =>
      {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, Object?> _withServerCorrectionCreateTimestamps(
          Map<String, Object?> data) =>
      {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  CommunityContent _content(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = _withIsoTimestamps(snapshot.data()!);
    data['contentId'] = snapshot.id;
    return CommunityContent.fromMap(data);
  }

  Source _source(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = _withIsoTimestamps(snapshot.data()!);
    data['sourceId'] = snapshot.id;
    return Source.fromMap(data);
  }

  Evidence _evidence(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = _withIsoTimestamps(snapshot.data()!);
    data['evidenceId'] = snapshot.id;
    return Evidence.fromMap(data);
  }

  ContentCorrection _correction(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = _withIsoTimestamps(snapshot.data()!);
    data['correctionId'] = snapshot.id;
    return ContentCorrection.fromMap(data);
  }

  Map<String, dynamic> _withIsoTimestamps(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    for (final field in ['createdAt', 'updatedAt']) {
      final value = normalized[field];
      if (value is Timestamp)
        normalized[field] = value.toDate().toUtc().toIso8601String();
    }
    return normalized;
  }

  String _encodeCursor(String id) => base64UrlEncode(utf8.encode(id));

  String _decodeCursor(String cursor) {
    try {
      final id = utf8.decode(base64Url.decode(base64Url.normalize(cursor)));
      if (id.trim().isEmpty) throw const FormatException();
      return id;
    } catch (_) {
      throw const CommunityError(
          CommunityErrorCode.invalidRequest, 'Invalid cursor');
    }
  }

  void _requireId(String value, CommunityErrorCode code) {
    if (value.trim().isEmpty) throw CommunityError(code, 'ID cannot be empty');
  }

  CommunityError _mapError(Object error, String message) {
    if (error is CommunityError) return error;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return CommunityError(CommunityErrorCode.forbidden, message);
        case 'unauthenticated':
          return CommunityError(CommunityErrorCode.unauthorized, message);
        case 'not-found':
          return CommunityError(CommunityErrorCode.notFound, message);
        case 'unavailable':
        case 'deadline-exceeded':
          return CommunityError(CommunityErrorCode.unavailable, message);
        case 'invalid-argument':
          return CommunityError(CommunityErrorCode.invalidRequest, message);
      }
    }
    return CommunityError(CommunityErrorCode.unknown, message);
  }
}
