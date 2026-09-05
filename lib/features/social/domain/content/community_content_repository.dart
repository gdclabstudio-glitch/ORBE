import '../community/community_pagination.dart';
import 'community_content.dart';

abstract class CommunityContentRepository {
  Future<CommunityContent> createContent({required CommunityContent content});

  Future<CommunityContent?> getContent({required String contentId});

  Future<CommunityPage<CommunityContent>> listCommunityContent({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });

  Future<CommunityContent> updateContent({required CommunityContent content});

  Future<Source> createSource({
    required String communityId,
    required Source source,
  });

  Future<CommunityPage<Source>> listSources({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });

  Future<Evidence> createEvidence({required Evidence evidence});

  Future<CommunityPage<Evidence>> listEvidence({
    required String contentId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });

  Future<ContentCorrection> createCorrection({
    required ContentCorrection correction,
  });

  Future<CommunityPage<ContentCorrection>> listCorrections({
    required String contentId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });
}
