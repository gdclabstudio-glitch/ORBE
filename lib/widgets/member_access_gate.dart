import 'package:flutter/material.dart';

import '../services/member_access_service.dart';

class MemberAccessGate extends StatefulWidget {
  final Widget child;

  const MemberAccessGate({super.key, required this.child});

  @override
  State<MemberAccessGate> createState() => _MemberAccessGateState();
}

class _MemberAccessGateState extends State<MemberAccessGate> {
  late Future<MemberAccessStatus> _accessFuture;

  @override
  void initState() {
    super.initState();
    _accessFuture = MemberAccessService().checkAccess();
  }

  void _retry() {
    setState(() => _accessFuture = MemberAccessService().checkAccess());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MemberAccessStatus>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final status = snapshot.data!;
        if (status.authorized) return widget.child;
        return Scaffold(
          appBar: AppBar(title: const Text('Acesso de membro')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status.authenticated
                        ? Icons.verified_user_outlined
                        : Icons.lock_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    status.authenticated
                        ? 'Libere seu acesso à folia'
                        : 'Área exclusiva para foliões cadastrados',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(status.message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: status.authenticated
                        ? _retry
                        : () => Navigator.pushNamed(context, '/login'),
                    icon: Icon(
                      status.authenticated
                          ? Icons.refresh
                          : Icons.login_outlined,
                    ),
                    label: Text(
                      status.authenticated ? 'Verificar novamente' : 'Entrar',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Criar cadastro'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
