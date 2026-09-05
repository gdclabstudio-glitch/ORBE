import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/admin_profile_service.dart';

class AdminAuthProvider extends ChangeNotifier {
  final AuthService _authService;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  AdminAuthProvider({required AuthService authService})
      : _authService = authService {
    _restoreSession();
  }

  Future<void> _restore_session_from_auth() async {
    try {
      _isAuthenticated = await _authService.isAdminAuthenticated();
      notifyListeners();
    } catch (_) {
      _isAuthenticated = false;
    }
  }

  Future<void> _restoreSession() async {
    await _restore_session_from_auth();
  }

  /// Perform admin login by authenticating with Firebase and then authorizing
  /// against the admin_profiles collection (or custom claims via AdminProfileService).
  /// Returns true only when both authentication and authorization succeed.
  Future<bool> login(String email, String password) async {
    final normalizedEmail = email.trim();

    // 1) Authenticate with Firebase (real user)
    final result = await _authService.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    if (result == null) {
      // Authentication failed
      return false;
    }

    // 2) Authorize: check admin profile / custom claims
    try {
      final adminSvc = AdminProfileService();
      final isAdmin = await adminSvc.isCurrentUserAdmin();
      if (!isAdmin) {
        // Not authorized as admin: sign out to avoid leaving a normal user signed in
        try {
          await _authService.signOut();
        } catch (_) {}
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }

      // Authorized as admin: persist admin session and grant access
      _isAuthenticated = true;
      try {
        await _authService.setAdminSession(true);
      } catch (_) {}
      notifyListeners();
      return true;
    } catch (e) {
      // On any error during authorization, ensure we don't leave a signed-in user
      try {
        await _authService.signOut();
      } catch (_) {}
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    try {
      await _authService.setAdminSession(false);
      await _authService.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
