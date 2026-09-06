enum FirestoreSocialErrorCode {
  invalidData,
  notFound,
  conflict,
  unavailable,
}

class FirestoreSocialException implements Exception {
  const FirestoreSocialException(this.code, this.message);

  final FirestoreSocialErrorCode code;
  final String message;

  @override
  String toString() => 'FirestoreSocialException($code): $message';
}
