/// Relationship state observed from the current user's perspective.
enum ConnectionStatus {
  /// No relevant relationship, request, or applicable block exists.
  none,

  /// The other user sent a pending connection request.
  pendingIncoming,

  /// The current user sent a pending connection request.
  pendingOutgoing,

  /// An active connection exists.
  connected,

  /// A block applies to this relationship.
  blocked,
}
