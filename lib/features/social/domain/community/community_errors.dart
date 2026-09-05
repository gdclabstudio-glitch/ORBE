enum CommunityErrorCode {
  invalidCommunity,
  invalidMembership,
  invalidRequest,
  notFound,
  unauthorized,
  forbidden,
  conflict,
  unavailable,
  unknown,
}

class CommunityError implements Exception {
  const CommunityError(this.code, this.message);

  final CommunityErrorCode code;
  final String message;

  @override
  String toString() => 'CommunityError($code): $message';
}
