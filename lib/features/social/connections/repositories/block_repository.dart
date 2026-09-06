import '../models/social_block.dart';

abstract class BlockRepository {
  Future<SocialBlock?> getBlock({
    required String blockerId,
    required String blockedUserId,
  });

  Future<bool> isBlocked({
    required String firstUserId,
    required String secondUserId,
  });

  Future<SocialBlock> createBlock(SocialBlock block);

  Future<SocialBlock> removeBlock({
    required String blockerId,
    required String blockedUserId,
    required String removedBy,
  });
}
