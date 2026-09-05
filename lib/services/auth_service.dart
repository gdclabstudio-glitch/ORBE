import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'storage_service.dart';
import 'storage_platform.dart';

/// Central AuthService that encapsulates FirebaseAuth, GoogleSignIn and
/// secure storage for tokens and admin session flags.

/// Unified auth status enum exposed by AuthService.authStatus
enum AuthStatus { unknown, unauthenticated, authenticated, admin }

enum AppRole { owner, admin, moderator, user, unknown }

enum AuthAccountState {
  unknown,
  active,
  emailNotVerified,
  disabled,
  blocked,
  sessionExpired,
  deleted,
}

class AuthService {
  /// Last FirebaseAuth error code seen by sign-in attempts. Useful for UI
  /// to render actionable messages without exposing exception details.
  String? lastAuthErrorCode;

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final StorageService _storage;
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;

  static const String _adminSessionKey = 'labomba_admin_session';
  static const String _idTokenKey = 'labomba_id_token';

  AppRole _currentRole = AppRole.unknown;

  /// Centralized auth status for the app. Consumers should observe this
  /// ValueNotifier instead of checking FirebaseAuth.instance.currentUser directly.
  static const AuthStatus initialAuthStatus = AuthStatus.unknown;
  final ValueNotifier<AuthStatus> authStatus = ValueNotifier<AuthStatus>(
    initialAuthStatus,
  );

  static AppRole roleFromClaims(Map<String, dynamic>? claims) {
    if (claims == null || claims.isEmpty) return AppRole.user;
    final role = claims['role'];
    if (role == 'owner' ||
        claims['owner'] == true ||
        claims['isOwner'] == true) {
      return AppRole.owner;
    }
    if (role == 'admin' ||
        claims['admin'] == true ||
        claims['isAdmin'] == true) {
      return AppRole.admin;
    }
    if (role == 'moderator' || claims['moderator'] == true) {
      return AppRole.moderator;
    }
    return AppRole.user;
  }

  static String friendlyAuthErrorMessage(String code) {
    switch (code) {
      case 'user-disabled':
        return 'Esta conta foi desativada. Entre em contato com o suporte.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Credenciais inválidas. Verifique e-mail e senha.';
      case 'email-already-in-use':
        return 'Este e-mail já está em uso por outra conta.';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres e ser mais segura.';
      case 'invalid-email':
        return 'Informe um e-mail válido antes de continuar.';
      case 'requires-recent-login':
        return 'Esta ação exige uma autenticação recente. Faça login novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas foram feitas. Tente novamente mais tarde.';
      case 'network-request-failed':
        return 'Não foi possível conectar ao servidor. Verifique sua conexão.';
      case 'user-token-expired':
      case 'session-expired':
        return 'Sua sessão expirou. Faça login novamente.';
      default:
        return 'Não foi possível completar a autenticação. Tente novamente.';
    }
  }

  static String friendlyAccountStateMessage(AuthAccountState state) {
    switch (state) {
      case AuthAccountState.active:
        return 'Conta ativa.';
      case AuthAccountState.emailNotVerified:
        return 'Confirme seu e-mail para continuar.';
      case AuthAccountState.disabled:
        return 'Esta conta foi desativada. Entre em contato com o suporte.';
      case AuthAccountState.blocked:
        return 'Sua conta está bloqueada temporariamente.';
      case AuthAccountState.sessionExpired:
        return 'Sua sessão expirou. Faça login novamente.';
      case AuthAccountState.deleted:
        return 'Esta conta foi removida ou não está mais disponível.';
      case AuthAccountState.unknown:
      default:
        return 'Estado da conta indisponível no momento.';
    }
  }

  bool get isMasterUser => _currentRole == AppRole.owner;

  Future<AppRole> refreshCurrentRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      _currentRole = AppRole.unknown;
      authStatus.value = AuthStatus.unauthenticated;
      return AppRole.unknown;
    }

    try {
      final tokenResult = await user.getIdTokenResult(true);
      final role = roleFromClaims(tokenResult.claims);
      _currentRole = role;
      if (role == AppRole.owner || role == AppRole.admin) {
        authStatus.value = AuthStatus.admin;
      } else {
        authStatus.value = AuthStatus.authenticated;
      }
      return role;
    } catch (_) {
      _currentRole = AppRole.unknown;
      authStatus.value = AuthStatus.authenticated;
      return AppRole.unknown;
    }
  }

  AuthService({StorageService? storageService})
      : _storage = storageService ?? PlatformStorageService() {
    _authStateSubscription = _auth.authStateChanges().listen((
      firebaseUser,
    ) async {
      try {
        if (firebaseUser == null) {
          _currentRole = AppRole.unknown;
          authStatus.value = AuthStatus.unauthenticated;
          return;
        }

        final role = await refreshCurrentRole();
        if (role == AppRole.owner || role == AppRole.admin) {
          authStatus.value = AuthStatus.admin;
        } else {
          authStatus.value = AuthStatus.authenticated;
        }
      } catch (_) {
        authStatus.value = AuthStatus.authenticated;
      }
    });
  }

  void dispose() {
    _authStateSubscription?.cancel();
  }

  bool isMasterCredentials({required String email, required String password}) {
    return false;
  }

  /// Optional init; main.dart already calls GoogleSignIn.instance.initialize()
  /// but this method is safe to call if necessary (it will surface errors).
  Future<void> initialize() async {
    try {
      await _googleSignIn.initialize();
    } catch (_) {
      // swallow - initialization may already have been done at bootstrap
    }
  }

  Future<Map<String, dynamic>?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // Clear last error on success
      lastAuthErrorCode = null;

      final role = await refreshCurrentRole();
      await setAdminSession(role == AppRole.owner || role == AppRole.admin);

      final resultMap = {
        'uid': user.uid,
        'displayName': user.displayName ?? 'Usuário',
        'email': user.email,
        'photoURL': user.photoURL,
      };

      return resultMap;
    } on firebase_auth.FirebaseAuthException catch (e) {
      lastAuthErrorCode = e.code;
      return null;
    } catch (e) {
      lastAuthErrorCode = 'unknown';
      return null;
    }
  }

  Future<Map<String, dynamic>?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalizedEmail = email.trim();
    final trimmedDisplayName = displayName?.trim();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty) {
        await user.updateDisplayName(trimmedDisplayName);
      }

      await user.sendEmailVerification();
      lastAuthErrorCode = null;

      return {
        'uid': user.uid,
        'displayName': user.displayName ?? trimmedDisplayName ?? 'Usuário',
        'email': user.email,
        'photoURL': user.photoURL,
      };
    } on firebase_auth.FirebaseAuthException catch (e) {
      lastAuthErrorCode = e.code;
      return null;
    } catch (_) {
      lastAuthErrorCode = 'unknown';
      return null;
    }
  }

  /// Performs Google Sign-In flow, signs in to Firebase and stores an ID token
  /// in secure storage when available. Returns a map with user info or null on
  /// cancellation.
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on PlatformException catch (_) {
      googleUser = null;
    } on Exception catch (_) {
      googleUser = null;
    } catch (_) {
      googleUser = null;
    }

    if (googleUser == null) {
      try {
        googleUser = await _googleSignIn.attemptLightweightAuthentication();
      } catch (_) {
        googleUser = null;
      }
    }

    if (googleUser == null) return null;

    try {
      final googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      const String? accessToken = null;

      final firebase_auth.OAuthCredential credential =
          firebase_auth.GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final firebase_auth.UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final firebase_auth.User? user = userCredential.user;

      if (user == null) return null;

      try {
        final token = await user.getIdToken();
        if (token != null) {
          await _storage.write(key: _idTokenKey, value: token);
        }
      } catch (_) {}

      return {
        'uid': user.uid,
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
      };
    } on firebase_auth.FirebaseAuthException catch (_) {
      return null;
    } on PlatformException catch (_) {
      return null;
    } catch (_) {
      throw Exception(
        'Google Sign-In indisponível no momento. Tente novamente.',
      );
    }
  }

  Future<bool> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      return false;
    }

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
      lastAuthErrorCode = null;
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      lastAuthErrorCode = e.code;
      return false;
    } catch (_) {
      lastAuthErrorCode = 'unknown';
      return false;
    }
  }

  Future<bool> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.sendEmailVerification();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      lastAuthErrorCode = e.code;
      return false;
    } catch (_) {
      lastAuthErrorCode = 'unknown';
      return false;
    }
  }

  Future<bool> reauthenticateWithPassword({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      return false;
    }

    try {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      lastAuthErrorCode = null;
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      lastAuthErrorCode = e.code;
      return false;
    } catch (_) {
      lastAuthErrorCode = 'unknown';
      return false;
    }
  }

  Future<bool> deleteCurrentUserWithPassword({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final reauthenticated = await reauthenticateWithPassword(
      password: password,
    );
    if (!reauthenticated) return false;

    try {
      await user.delete();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      lastAuthErrorCode = e.code;
      return false;
    } catch (_) {
      lastAuthErrorCode = 'unknown';
      return false;
    }
  }

  Future<AuthAccountState> evaluateCurrentUserState() async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthAccountState.sessionExpired;
    }

    try {
      await user.reload();
    } catch (_) {
      return AuthAccountState.sessionExpired;
    }

    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) {
      return AuthAccountState.deleted;
    }

    if (refreshedUser.email != null && !refreshedUser.emailVerified) {
      return AuthAccountState.emailNotVerified;
    }

    return AuthAccountState.active;
  }

  /// Signs out from Firebase and Google and clears stored tokens/sessions.
  Future<void> signOut() async {
    _currentRole = AppRole.unknown;
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (_) {}
    try {
      await _storage.delete(key: _idTokenKey);
    } catch (_) {}
    try {
      await _storage.delete(key: _adminSessionKey);
    } catch (_) {}
  }

  /// Admin session persistence (uses secure storage only as a UX cache; it is not
  /// authoritative authorization. Real authorization must come from Firebase custom claims.)
  Future<void> setAdminSession(bool value) async {
    try {
      if (value) {
        await _storage.write(key: _adminSessionKey, value: '1');
      } else {
        await _storage.delete(key: _adminSessionKey);
      }
    } catch (_) {}
  }

  Future<bool> isAdminAuthenticated() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final tokenResult = await user.getIdTokenResult(true);
      final role = roleFromClaims(tokenResult.claims);
      final isAdmin = role == AppRole.owner || role == AppRole.admin;
      if (isAdmin) {
        await setAdminSession(true);
      } else {
        await setAdminSession(false);
      }
      return isAdmin;
    } catch (_) {
      return false;
    }
  }

  /// Expose current Firebase user (if any)
  firebase_auth.User? get currentUser => _auth.currentUser;

  /// Reload the current Firebase user from the backend and refresh local state
  Future<void> reloadCurrentUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (_) {}
  }

  /// Read stored id token (if any)
  Future<String?> readStoredIdToken() => _storage.read(key: _idTokenKey);

  /// Returns a valid ID token when possible. If [forceRefresh] is true
  /// it forces a refresh from Firebase; otherwise it will try to read from
  /// secure storage or current user.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      // Prefer the Firebase User token (fresh)
      final user = _auth.currentUser;
      if (user != null) {
        final token = await user.getIdToken(forceRefresh);
        if (token != null) {
          try {
            await _storage.write(key: _idTokenKey, value: token);
          } catch (_) {}
          return token;
        }
      }

      // Fallback to stored token
      final stored = await _storage.read(key: _idTokenKey);
      return stored;
    } catch (_) {
      // On any error, attempt stored token
      try {
        return await _storage.read(key: _idTokenKey);
      } catch (_) {
        return null;
      }
    }
  }
}
