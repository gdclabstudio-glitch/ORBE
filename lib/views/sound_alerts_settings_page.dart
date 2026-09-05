import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';

class SoundAlertsSettingsPage extends StatefulWidget {
  const SoundAlertsSettingsPage({super.key});

  @override
  State<SoundAlertsSettingsPage> createState() =>
      _SoundAlertsSettingsPageState();
}

class _SoundAlertsSettingsPageState extends State<SoundAlertsSettingsPage> {
  static const _soundKey = 'settings_alert_sound';
  static const _visualKey = 'settings_alert_visual';
  static const _hapticKey = 'settings_alert_haptic';

  late final StorageService _storage;
  bool _loading = true;
  bool _soundEnabled = true;
  bool _visualEnabled = true;
  bool _hapticEnabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = context.read<StorageService>();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final values = await Future.wait([
      _storage.read(key: _soundKey),
      _storage.read(key: _visualKey),
      _storage.read(key: _hapticKey),
    ]);
    if (!mounted) return;
    setState(() {
      _soundEnabled = values[0] != 'false';
      _visualEnabled = values[1] != 'false';
      _hapticEnabled = values[2] != 'false';
      _loading = false;
    });
  }

  Future<void> _setPreference(String key, bool value) async {
    await _storage.write(key: key, value: value ? 'true' : 'false');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sons e efeitos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Alertas La Bomba',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up_outlined),
                        title: const Text('Som da explosão'),
                        subtitle: const Text('Reproduzir o alerta sonoro'),
                        value: _soundEnabled,
                        onChanged: (value) async {
                          setState(() => _soundEnabled = value);
                          await _setPreference(_soundKey, value);
                        },
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.auto_awesome_outlined),
                        title: const Text('Efeitos visuais'),
                        subtitle: const Text('Exibir a animação da explosão'),
                        value: _visualEnabled,
                        onChanged: (value) async {
                          setState(() => _visualEnabled = value);
                          await _setPreference(_visualKey, value);
                        },
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.vibration_outlined),
                        title: const Text('Vibração e resposta tátil'),
                        subtitle: const Text('Usar resposta tátil nos alertas'),
                        value: _hapticEnabled,
                        onChanged: (value) async {
                          setState(() => _hapticEnabled = value);
                          await _setPreference(_hapticKey, value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
