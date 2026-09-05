import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/event_config_provider.dart';
import '../../providers/shop_provider.dart';
import '../../theme/app_theme.dart';

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  Future<void> _openSupport(BuildContext context) async {
    final msg = context.read<EventConfigProvider>().whatsappSupportMessage;
    await context.read<ShopProvider>().launchWhatsApp(message: msg);
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Column(
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 32),
        const Text(
          'Dúvidas? Fale com a nossa equipe.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _openSupport(context),
          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryLight),
          icon: const Icon(Icons.help_outline),
          label: const Text('Suporte e Informações'),
        ),
        const SizedBox(height: 48),
        Text(
          '© $currentYear Bloco LaBomba. Todos os direitos reservados.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white24, fontSize: 12),
        ),
      ],
    );
  }
}
