import 'package:flutter/foundation.dart';

import '../../domain/community/community_errors.dart';
import '../../domain/community/community_membership.dart';
import '../../domain/community/community_pagination.dart';
import '../../domain/community/community_read_service.dart';
import '../../domain/community/community_write_service.dart';
import '../../models/social_community.dart';

class CommunityUiController extends ChangeNotifier {
  CommunityUiController({
    required CommunityReadService readService,
    required CommunityWriteService writeService,
    required this.userId,
  })  : _readService = readService,
        _writeService = writeService;

  final CommunityReadService _readService;
  final CommunityWriteService _writeService;
  final String? userId;

  final List<SocialCommunity> _communities = [];
  final Map<String, CommunityMembership?> _memberships = {};
  final Map<String, Future<CommunityMembership?>> _membershipRequests = {};
  final Map<String, List<CommunityMembership>> _members = {};
  final Map<String, String?> _memberCursors = {};
  final Map<String, CommunityError?> _memberErrors = {};
  final Set<String> _loadingMembers = {};
  final Set<String> _loadingMoreMembers = {};
  String? _nextCursor;
  CommunityError? _error;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isCreating = false;
  String? _joiningCommunityId;
  bool _disposed = false;

  List<SocialCommunity> get communities => List.unmodifiable(_communities);
  String? get nextCursor => _nextCursor;
  CommunityError? get error => _error;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isCreating => _isCreating;
  String? get joiningCommunityId => _joiningCommunityId;
  bool get hasNextPage => _nextCursor != null;

  List<CommunityMembership> membersFor(String communityId) =>
      List.unmodifiable(_members[communityId] ?? const []);

  CommunityError? membersErrorFor(String communityId) =>
      _memberErrors[communityId];

  bool isLoadingMembers(String communityId) =>
      _loadingMembers.contains(communityId);

  bool isLoadingMoreMembers(String communityId) =>
      _loadingMoreMembers.contains(communityId);

  bool hasMoreMembers(String communityId) =>
      _memberCursors[communityId] != null;

  Future<void> loadMembers(String communityId, {bool refresh = true}) async {
    if (_loadingMembers.contains(communityId) ||
        _loadingMoreMembers.contains(communityId)) return;
    if (refresh) {
      _members[communityId] = [];
      _memberCursors[communityId] = null;
    }
    _loadingMembers.add(communityId);
    _memberErrors.remove(communityId);
    _notify();
    try {
      final page = await _readService.listMembers(
        communityId: communityId,
        page: CommunityPageRequest(cursor: _memberCursors[communityId]),
      );
      _members[communityId] = [
        ...(_members[communityId] ?? const []),
        ...page.items.where((membership) => membership.isActive),
      ];
      _memberCursors[communityId] = page.nextCursor;
    } catch (error) {
      _memberErrors[communityId] = _asCommunityError(error);
    } finally {
      _loadingMembers.remove(communityId);
      _notify();
    }
  }

  Future<void> loadMoreMembers(String communityId) async {
    if (_loadingMembers.contains(communityId) ||
        _loadingMoreMembers.contains(communityId) ||
        !hasMoreMembers(communityId)) return;
    _loadingMoreMembers.add(communityId);
    _memberErrors.remove(communityId);
    _notify();
    try {
      final page = await _readService.listMembers(
        communityId: communityId,
        page: CommunityPageRequest(cursor: _memberCursors[communityId]),
      );
      _members[communityId] = [
        ...(_members[communityId] ?? const []),
        ...page.items.where((membership) => membership.isActive),
      ];
      _memberCursors[communityId] = page.nextCursor;
    } catch (error) {
      _memberErrors[communityId] = _asCommunityError(error);
    } finally {
      _loadingMoreMembers.remove(communityId);
      _notify();
    }
  }

  Future<void> load({bool refresh = true}) async {
    if (_isLoading || _isLoadingMore) return;
    if (refresh) {
      _communities.clear();
      _nextCursor = null;
    }
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final page = await _readService.listCommunities(
        page: CommunityPageRequest(cursor: _nextCursor),
      );
      _communities.addAll(page.items);
      _nextCursor = page.nextCursor;
    } catch (error) {
      _error = _asCommunityError(error);
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasNextPage) return;
    _isLoadingMore = true;
    _error = null;
    _notify();
    try {
      final page = await _readService.listCommunities(
        page: CommunityPageRequest(cursor: _nextCursor),
      );
      _communities.addAll(page.items);
      _nextCursor = page.nextCursor;
    } catch (error) {
      _error = _asCommunityError(error);
    } finally {
      _isLoadingMore = false;
      _notify();
    }
  }

  Future<CommunityMembership?> membershipFor(String communityId) {
    if (userId == null || userId!.trim().isEmpty) {
      return Future<CommunityMembership?>.value();
    }
    final cached = _memberships[communityId];
    if (_memberships.containsKey(communityId)) {
      return Future<CommunityMembership?>.value(cached);
    }
    final pending = _membershipRequests[communityId];
    if (pending != null) return pending;
    final request = _readService
        .getMembership(userId: userId!, communityId: communityId)
        .then((membership) {
      _memberships[communityId] = membership;
      _membershipRequests.remove(communityId);
      _notify();
      return membership;
    }).catchError((error) {
      _membershipRequests.remove(communityId);
      _error = _asCommunityError(error);
      _notify();
      throw error;
    });
    _membershipRequests[communityId] = request;
    return request;
  }

  CommunityMembership? cachedMembershipFor(String communityId) =>
      _memberships[communityId];

  Future<CommunityMembership?> join(String communityId) async {
    if (_joiningCommunityId != null) return null;
    _joiningCommunityId = communityId;
    _error = null;
    _notify();
    try {
      final membership = await _writeService.joinCommunity(
        communityId: communityId,
      );
      _memberships[communityId] = membership;
      return membership;
    } catch (error) {
      _error = _asCommunityError(error);
      rethrow;
    } finally {
      _joiningCommunityId = null;
      _notify();
    }
  }

  Future<SocialCommunity?> createCommunity({
    required String name,
    String? description,
  }) async {
    if (_isCreating) return null;
    _isCreating = true;
    _error = null;
    _notify();
    try {
      final community = await _writeService.createCommunity(
        name: name,
        description: description,
      );
      _communities.insert(0, community);
      return community;
    } catch (error) {
      _error = _asCommunityError(error);
      rethrow;
    } finally {
      _isCreating = false;
      _notify();
    }
  }

  static String friendlyError(Object error) {
    final communityError = error is CommunityError ? error : null;
    switch (communityError?.code) {
      case CommunityErrorCode.unauthorized:
        return 'Entre na sua conta para continuar.';
      case CommunityErrorCode.forbidden:
        return 'Você não tem acesso a esta ação.';
      case CommunityErrorCode.notFound:
        return 'Esta comunidade não está disponível.';
      case CommunityErrorCode.conflict:
        return 'Esta ação não pode ser concluída neste estado.';
      case CommunityErrorCode.unavailable:
        return 'Não foi possível conectar agora.';
      default:
        return 'Não foi possível concluir a ação.';
    }
  }

  CommunityError _asCommunityError(Object error) => error is CommunityError
      ? error
      : const CommunityError(
          CommunityErrorCode.unknown,
          'Unexpected community error',
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
