import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AdminGuard checks the current user's Firebase custom claims (isAdmin or role)
/// and renders [child] when authorized. If not authorized it shows an AccessDenied
/// view. This class performs a runtime check using getIdTokenResult so no secret
/// is embedded in the client.
class AdminGuard extends StatefulWidget {
  final Widget child;
  final Widget? onDenied;

  const AdminGuard({super.key, required this.child, this.onDenied});

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  bool? _isAdmin;

  @override
  void initState() {
    super.initState();
    _checkClaims();
  }

  Future<void> _checkClaims() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isAdmin = false);
        return;
      }
      final idr = await user.getIdTokenResult(true);
      final claims = idr.claims ?? {};
      final isAdmin = (claims['owner'] == true) ||
          (claims['isOwner'] == true) ||
          (claims['admin'] == true) ||
          (claims['isAdmin'] == true) ||
          (claims['role'] == 'owner') ||
          (claims['role'] == 'admin');
      setState(() => _isAdmin = isAdmin);
    } catch (_) {
      setState(() => _isAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdmin == null)
      return const Center(child: CircularProgressIndicator());
    if (_isAdmin == true) return widget.child;

    return widget.onDenied ?? const _AccessDenied();
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso Negado')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Você não tem permissão para acessar esta área.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
