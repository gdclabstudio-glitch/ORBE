import 'package:cloud_functions/cloud_functions.dart';

abstract class SocialOperationClient {
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  );
}

class FirebaseSocialOperationClient implements SocialOperationClient {
  FirebaseSocialOperationClient({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    final result = await _functions.httpsCallable('socialOperation').call({
      'operation': operation,
      ...payload,
    });
    final data = result.data;
    if (data is! Map) {
      throw StateError('socialOperation returned an invalid response');
    }
    return Map<String, dynamic>.from(data);
  }
}
