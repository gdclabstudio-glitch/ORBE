import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/street_mode_service.dart';

class StreetModeSettingsPage extends StatelessWidget {
  const StreetModeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final streetMode = context.watch<StreetModeService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Modo Rua')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Economizar bateria e dados'),
              subtitle: Text(
                streetMode.enabled
                    ? 'Vídeos não iniciam automaticamente e animações são reduzidas.'
                    : 'Reduza o consumo durante o bloco com um toque.',
              ),
              value: streetMode.enabled,
              onChanged: streetMode.setEnabled,
              secondary: const Icon(Icons.battery_saver_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
