import 'package:cloud_firestore/cloud_firestore.dart';

class FoliaoProfile {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? email;

  const FoliaoProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.email,
  });

  factory FoliaoProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return FoliaoProfile(
      uid: document.id,
      displayName: data['displayName'] as String? ?? 'Folião',
      photoUrl: data['photoUrl'] as String?,
      email: data['email'] as String?,
    );
  }
}

class FoliaoDirectoryService {
  final FirebaseFirestore _firestore;

  FoliaoDirectoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<FoliaoProfile>> streamFoliaos({String? excludeUid}) {
    return _firestore
        .collection('users')
        .orderBy('displayName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(FoliaoProfile.fromDocument)
              .where((profile) => profile.uid != excludeUid)
              .toList(growable: false),
        );
  }
}
