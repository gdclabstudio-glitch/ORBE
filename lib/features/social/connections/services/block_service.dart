import '../models/social_block.dart';

abstract class BlockService {
  Future<SocialBlock> createBlock({
    required String blockerId,
    required String blockedUserId,
  });

  Future<SocialBlock> removeBlock({
    required String blockerId,
    required String blockedUserId,
    required String removedBy,
  });
}
