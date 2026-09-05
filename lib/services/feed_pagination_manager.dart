import 'package:cloud_firestore/cloud_firestore.dart';

/// Encapsulates pagination state for the social feed.
/// Memoizes the future to prevent duplicate Firestore queries on rebuilds.
class FeedPaginationManager {
  final FirebaseFirestore _firestore;
  final int pageSize;

  static const String _postsCollection = 'posts';

  DocumentSnapshot<Map<String, dynamic>>? _lastVisiblePost;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;
  final Set<String> _seenPostIds = <String>{};

  // Memoized future to prevent duplicate queries on rebuild
  Future<QuerySnapshot<Map<String, dynamic>>>? _currentPageFuture;

  Exception? _lastError;

  FeedPaginationManager(
    this._firestore, {
    this.pageSize = 20,
  });

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePosts => _hasMorePosts;
  Exception? get lastError => _lastError;

  /// Get the memoized future for the current page.
  /// If already loading, returns the same future to prevent duplicate queries.
  Future<QuerySnapshot<Map<String, dynamic>>> getCurrentPageFuture() {
    _currentPageFuture ??= _loadPostsPage();
    return _currentPageFuture!;
  }

  /// Load the next page of posts.
  /// Requires the current page to be loaded first.
  Future<QuerySnapshot<Map<String, dynamic>>> loadNextPage() async {
    if (_isLoadingMore || !_hasMorePosts) {
      // Return empty query snapshot when no more posts available
      return _firestore.collection(_postsCollection).limit(0).get();
    }

    _isLoadingMore = true;
    _lastError = null;

    try {
      final snap = await _loadPostsPage();
      if (snap.docs.isEmpty) {
        _hasMorePosts = false;
      } else {
        _lastVisiblePost = snap.docs.last;
        _hasMorePosts = snap.docs.length >= pageSize;
      }

      // Update memoized future
      _currentPageFuture = Future.value(snap);

      return snap;
    } catch (e) {
      _lastError = e is Exception ? e : Exception('Unknown error: $e');
      rethrow;
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Refresh to first page.
  void reset() {
    _lastVisiblePost = null;
    _hasMorePosts = true;
    _isLoadingMore = false;
    _lastError = null;
    _seenPostIds.clear();
    _currentPageFuture = null;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _loadPostsPage() async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_postsCollection)
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (_lastVisiblePost != null) {
      query = query.startAfterDocument(_lastVisiblePost!);
    }

    try {
      final snapshot = await query.get();
      final uniqueDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc in snapshot.docs) {
        if (_seenPostIds.add(doc.id)) {
          uniqueDocs.add(doc);
        }
      }
      if (uniqueDocs.isEmpty && snapshot.docs.isNotEmpty) {
        return snapshot;
      }
      if (uniqueDocs.isNotEmpty) {
        _lastVisiblePost = uniqueDocs.last;
      }
      return snapshot;
    } catch (e) {
      _lastError = e is Exception ? e : Exception('Query failed: $e');
      rethrow;
    }
  }
}
