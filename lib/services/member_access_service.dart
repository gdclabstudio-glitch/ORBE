import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberAccessStatus {
  final bool authenticated;
  final bool authorized;
  final String message;

  const MemberAccessStatus({
    required this.authenticated,
    required this.authorized,
    required this.message,
  });
}

class MemberAccessService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  MemberAccessService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<MemberAccessStatus> checkAccess() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const MemberAccessStatus(
        authenticated: false,
        authorized: false,
        message: 'Entre com sua conta para validar sua participação no bloco.',
      );
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) {
      return const MemberAccessStatus(
        authenticated: false,
        authorized: false,
        message: 'Sua sessão expirou. Entre novamente para continuar.',
      );
    }

    final emailVerified = refreshedUser.emailVerified;
    final phoneVerified = refreshedUser.phoneNumber?.isNotEmpty == true;
    try {
      final snapshot = await _firestore
          .collection('admin_profiles')
          .doc(refreshedUser.uid)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final approved = data['memberApproved'] == true ||
          data['isMember'] == true ||
          data['abadáVerified'] == true ||
          data['ticketVerified'] == true;
      if (emailVerified || phoneVerified || approved) {
        return const MemberAccessStatus(
          authenticated: true,
          authorized: true,
          message: 'Acesso de membro confirmado.',
        );
      }
    } on FirebaseException {
      return const MemberAccessStatus(
        authenticated: true,
        authorized: false,
        message:
            'Não foi possível confirmar seu cadastro agora. Tente novamente.',
      );
    }

    return const MemberAccessStatus(
      authenticated: true,
      authorized: false,
      message:
          'Confirme seu e-mail ou telefone, ou aguarde a validação do abadá/ingresso pelo bloco.',
    );
  }
}
