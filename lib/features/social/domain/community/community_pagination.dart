class CommunityPage<T> {
  const CommunityPage({
    required this.items,
    this.nextCursor,
  });

  final List<T> items;
  final String? nextCursor;

  bool get hasNextPage => nextCursor != null;
}

class CommunityPageRequest {
  const CommunityPageRequest({
    this.limit = 20,
    this.cursor,
  }) : assert(limit > 0 && limit <= 100);

  final int limit;
  final String? cursor;
}
