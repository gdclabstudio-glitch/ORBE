import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_feedback.dart';

class AboutAndTermsPage extends StatelessWidget {
  const AboutAndTermsPage({super.key});

  static const _version = 'v1.0.0+1';
  static const _terms = '''
Ao utilizar o aplicativo ORBE você concorda com os termos e condições.

Este é um texto de exemplo — substitua pelo texto oficial de Termos de Uso e Política de Privacidade do produto.

Coleta de dados: armazenamos memórias localmente e, quando autorizado, dados em backend.

Privacidade: respeitamos sua privacidade. Consulte a Política de Privacidade completa.''';
  static const _privacy = '''
A Política de Privacidade descreve como coletamos, usamos e protegemos os dados do usuário.

Este é um texto de exemplo — substitua pelo texto oficial.''';

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
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Repositório do projeto'),
            onTap: () => _openLink(
              context,
              Uri.parse('https://github.com/COSTAIVXX/Labomba_app'),
            ),
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
          const Text(_terms),
          const SizedBox(height: 20),
          Text(
            'Política de Privacidade',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(_privacy),
        ],
      ),
    );
  }
}
