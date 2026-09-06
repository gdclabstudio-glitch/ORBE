import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_feedback.dart';

class AboutAndTermsPage extends StatelessWidget {
  const AboutAndTermsPage({super.key});

  static const _version = 'v1.0.0+1';
  Future<void> _openLink(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppFeedback.showError(context, 'Não foi possível abrir este link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o app e termos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.celebration, size: 64, color: Colors.deepOrange),
          const SizedBox(height: 12),
          Text(
            'ORBE',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Sua comunidade em movimento',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(_version, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Desenvolvimento'),
            subtitle: Text('Desenvolvido com carinho pelo time GDC Labs.'),
          ),
          const Divider(),
          const Text(
            'Links rápidos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Informações do produto'),
            subtitle: Text('ORBE é uma comunidade em movimento.'),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Fale com o suporte'),
            onTap: () => _openLink(
              context,
              Uri(scheme: 'mailto', path: 'suporte@orbe.app'),
            ),
          ),
          const Divider(),
          Text(
            'Termos de Uso',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'A versão legal definitiva dos Termos de Uso deve ser fornecida e aprovada pelos responsáveis pelo produto ORBE.',
          ),
          const SizedBox(height: 20),
          Text(
            'Política de Privacidade',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'A versão legal definitiva da Política de Privacidade deve ser fornecida e aprovada pelos responsáveis pelo produto ORBE.',
          ),
        ],
      ),
    );
  }
}
