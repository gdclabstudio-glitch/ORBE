import 'package:cloud_firestore/cloud_firestore.dart';

import '../identities.dart';
import '../models/social_block.dart';
import '../repositories/block_repository.dart';
import 'firestore_social_errors.dart';
import 'firestore_social_mappers.dart';
import 'social_operation_client.dart';

class FirestoreBlockRepository implements BlockRepository {
  FirestoreBlockRepository({
    FirebaseFirestore? firestore,
    SocialOperationClient? operationClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _operationClient = operationClient ?? FirebaseSocialOperationClient();

  static const _blocks = 'blocks';
  final FirebaseFirestore _firestore;
  final SocialOperationClient _operationClient;

  @override
  Future<SocialBlock?> getBlock({
    required String blockerId,
    required String blockedUserId,
  }) async {
    final id = BlockIdentity.forDirection(blockerId, blockedUserId);
    final snapshot = await _firestore.collection(_blocks).doc(id).get();
    return snapshot.exists
        ? FirestoreSocialMappers.blockFromMap(id, snapshot.data()!)
        : null;
  }

  @override
  Future<bool> isBlocked({
    required String firstUserId,
    required String secondUserId,
  }) async {
    final blocks = await Future.wait([
      getBlock(blockerId: firstUserId, blockedUserId: secondUserId),
      getBlock(blockerId: secondUserId, blockedUserId: firstUserId),
    ]);
    return blocks.any((block) => block?.status == SocialBlockStatus.active);
  }

  @override
  Future<SocialBlock> createBlock(SocialBlock block) async {
    if (block.status != SocialBlockStatus.active) {
      throw const FirestoreSocialException(
        FirestoreSocialErrorCode.conflict,
        'A new block must be active',
      );
    }
    final id = BlockIdentity.forDirection(
      block.blockerId,
      block.blockedUserId,
    );
    await _operationClient.call('createBlock', {
      'blockerId': block.blockerId,
      'blockedUserId': block.blockedUserId,
      'expectedId': id,
    });
    return _readRequired(id);
  }

  @override
  Future<SocialBlock> removeBlock({
    required String blockerId,
    required String blockedUserId,
    required String removedBy,
  }) async {
    if (removedBy.trim().isEmpty) {
      throw const FirestoreSocialException(
        FirestoreSocialErrorCode.invalidData,
        'removedBy must not be empty',
      );
    }
    final id = BlockIdentity.forDirection(blockerId, blockedUserId);
    await _operationClient.call('removeBlock', {
      'blockerId': blockerId,
      'blockedUserId': blockedUserId,
      'expectedId': id,
    });
    return _readRequired(id);
  }

  Future<SocialBlock> _readRequired(String id) async {
    final snapshot = await _firestore.collection(_blocks).doc(id).get();
    if (!snapshot.exists) {
      throw _unavailable('Block was not readable after write');
    }
    return FirestoreSocialMappers.blockFromMap(id, snapshot.data()!);
  }

  FirestoreSocialException _unavailable(String message) =>
      FirestoreSocialException(FirestoreSocialErrorCode.unavailable, message);
}
