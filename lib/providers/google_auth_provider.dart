import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class GoogleAuthData {
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String uid;

  GoogleAuthData({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });
}

class GoogleAuthProvider extends ChangeNotifier {
  final AuthService _authService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  GoogleAuthProvider({required AuthService authService})
      : _authService = authService;

  Future<GoogleAuthData?> signInWithGoogle() async {
    _setLoading(true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) return null;
      return GoogleAuthData(
        uid: result['uid'] as String,
        displayName: result['displayName'] as String?,
        email: result['email'] as String?,
        photoUrl: result['photoURL'] as String?,
      );
    } on PlatformException catch (e) {
      debugPrint('Erro de Plataforma no Google Sign-In: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Erro desconhecido no Google Sign-In: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh the current Firebase user information and notify listeners so UI updates immediately
  Future<void> refresh() async {
    _setLoading(true);
    try {
      await _authService.reloadCurrentUser();
    } catch (e) {
      debugPrint('GoogleAuthProvider.refresh error: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// A convenience getter that maps current Firebase user to GoogleAuthData (or null)
  GoogleAuthData? get currentUserData {
    final u = _authService.currentUser;
    if (u == null) return null;
    return GoogleAuthData(
      uid: u.uid,
      displayName: u.displayName,
      email: u.email,
      photoUrl: u.photoURL,
    );
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Erro ao sair: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
