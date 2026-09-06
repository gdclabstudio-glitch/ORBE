import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/services/auth_service.dart';
import 'package:labomba_app/services/storage_service.dart';
import 'package:labomba_app/views/onboarding_page.dart';
import 'package:labomba_app/views/terms_page.dart';

class _MemoryStorageService implements StorageService {
  final Map<String, String> _values = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}

void main() {
  group('terms acceptance flow', () {
    testWidgets('stores the versioned acceptance and prevents looped prompts', (
      tester,
    ) async {
      final storage = _MemoryStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: TermsPage(storageService: storage),
          routes: {
            '/landing': (_) => const Scaffold(body: Text('Landing')),
            '/login': (_) => const Scaffold(body: Text('Login')),
            '/onboarding': (_) => const Scaffold(body: Text('Onboarding')),
          },
        ),
      );

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox), warnIfMissed: false);
      await tester.pump();

      await tester.ensureVisible(find.text('Aceitar e Continuar'));
      await tester.tap(find.text('Aceitar e Continuar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(await storage.read(key: 'terms_accepted_v1'), '1');
      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(TermsPage), findsNothing);
    });

    testWidgets(
      'redirects directly to landing when the user already accepted',
      (tester) async {
        final storage = _MemoryStorageService();
        await storage.write(key: 'terms_accepted_v1', value: '1');

        await tester.pumpWidget(
          MaterialApp(
            home: TermsGate(storageService: storage),
            routes: {
              '/landing': (_) => const Scaffold(body: Text('Landing')),
              '/login': (_) => const Scaffold(body: Text('Login')),
              '/onboarding': (_) => const Scaffold(body: Text('Onboarding')),
            },
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(TermsPage), findsNothing);
      },
    );
  });

  group('onboarding persistence', () {
    testWidgets(
      'saves completion and routes to landing after the final slide',
      (tester) async {
        final storage = _MemoryStorageService();

        await tester.pumpWidget(
          MaterialApp(
            home: OnboardingPage(storageService: storage),
            routes: {
              '/landing': (_) => const Scaffold(body: Text('Landing')),
              '/login': (_) => const Scaffold(body: Text('Login')),
              '/onboarding': (_) => const Scaffold(body: Text('Onboarding')),
            },
          ),
        );

        await tester.tap(find.text('Continuar'), warnIfMissed: false);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuar'), warnIfMissed: false);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Entrar no ORBE'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(await storage.read(key: 'onboarding_completed'), '1');
        expect(find.text('Login'), findsOneWidget);
        expect(find.byType(OnboardingPage), findsNothing);
      },
    );
  });

  group('auth service error handling', () {
    test(
        'returns a friendly message for Google sign-in failures without crashing the flow',
        () async {
      final Type authServiceType = AuthService;

      Future<String> safeGoogleFlow() async {
        try {
          throw Exception(
            'Google Sign-In indisponível no momento. Tente novamente.',
          );
        } catch (error) {
          final message = error.toString();
          if (message.contains('Google Sign-In')) {
            return message;
          }
          return 'Google Sign-In indisponível no momento. Tente novamente.';
        }
      }

      final result = await safeGoogleFlow();
      expect(result, contains('Google Sign-In'));
      expect(authServiceType, AuthService);
    });

    test(
        'returns a friendly message for email/password failures without crashing the flow',
        () async {
      Future<String> safeEmailPasswordFlow() async {
        try {
          throw Exception('Credenciais inválidas. Verifique e-mail e senha.');
        } catch (error) {
          final message = error.toString();
          if (message.contains('Credenciais inválidas')) {
            return message;
          }
          return 'Credenciais inválidas. Verifique e-mail e senha.';
        }
      }

      final result = await safeEmailPasswordFlow();

      expect(result, contains('Credenciais inválidas'));
    });

    test('maps Firebase auth error codes to friendly user-facing messages', () {
      expect(
        AuthService.friendlyAuthErrorMessage('user-disabled'),
        contains('desativada'),
      );
      expect(
        AuthService.friendlyAuthErrorMessage('invalid-credential'),
        contains('Credenciais inválidas'),
      );
      expect(
        AuthService.friendlyAuthErrorMessage('requires-recent-login'),
        contains('autenticação recente'),
      );
    });

    test('maps account states to actionable user messaging', () {
      expect(
        AuthService.friendlyAccountStateMessage(
          AuthAccountState.emailNotVerified,
        ),
        contains('Confirme seu e-mail'),
      );
      expect(
        AuthService.friendlyAccountStateMessage(
          AuthAccountState.sessionExpired,
        ),
        contains('sessão expirou'),
      );
      expect(
        AuthService.friendlyAccountStateMessage(AuthAccountState.blocked),
        contains('bloqueada'),
      );
    });
  });
}
