import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:labomba_app/config/event_config.dart';
import 'package:labomba_app/providers/shop_provider.dart';
import 'package:labomba_app/core/theme/app_theme.dart';

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  Future<void> _openSupport(BuildContext context) async {
    await context.read<ShopProvider>().launchWhatsApp(
          message: EventConfig.whatsappSupportMessage,
        );
  }

  void _openTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Cor de fundo segura para o modal
          title: const Text(
            'Termos de Responsabilidade',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Aqui vão constar todas as regras, diretrizes e o termo de responsabilidade do evento. '
              'Você pode substituir este texto pela sua versão oficial completa quando quiser.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fechar',
                style: TextStyle(color: AppTheme.primaryLight),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Column(
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            TextButton.icon(
              onPressed: () => _openSupport(context),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryLight,
              ),
              icon: const Icon(Icons.help_outline),
              label: const Text('Suporte / Dúvidas'),
            ),
            TextButton.icon(
              onPressed: () => _openTerms(context),
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Termos de Responsabilidade'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          '© $currentYear Bloco LaBomba. Todos os direitos reservados.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white24, fontSize: 12),
        ),
      ],
    );
  }
}
