import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../services/admin_profile_service.dart';
import '../services/auth_service.dart';
import '../providers/google_auth_provider.dart';

import 'package:labomba_app/widgets/user_appbar_actions.dart';

import '../models/admin_profile.dart';
import '../widgets/app_feedback.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final StorageService _storage;
  bool _loading = true;
  String _displayName = '';
  String _bio = '';
  final Map<String, String> _socialLinks = {};
  bool _notificationsEnabled = true;
  bool _darkTheme = true;
  bool _shareUsage = false;

  static const _keyDisplayName = 'settings_display_name';
  static const _keyNotifications = 'settings_notifications';
  static const _keyDarkTheme = 'settings_dark_theme';
  static const _keyShareUsage = 'settings_share_usage';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = context.read<StorageService>();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      String? dn = await _storage.read(key: _keyDisplayName);
      final notif = await _storage.read(key: _keyNotifications);
      final theme = await _storage.read(key: _keyDarkTheme);
      final share = await _storage.read(key: _keyShareUsage);
      AdminProfile? profile;
      if (context.read<AuthService>().currentUser != null) {
        profile = await AdminProfileService(storage: _storage)
            .getCurrentUserProfile();
      }

      // If no local display name and user is signed in, try fetch from profile service
      if ((dn == null || dn.isEmpty) && mounted) {
        try {
          final auth = context.read<AuthService>();
          if (auth.currentUser != null) {
            final profile = await AdminProfileService(storage: _storage)
                .getCurrentUserProfile();
            if (profile?.displayName != null &&
                profile!.displayName!.isNotEmpty) {
              dn = profile.displayName;
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _displayName = dn ?? profile?.displayName ?? '';
        _bio = profile?.bio ?? '';
        _socialLinks
          ..clear()
          ..addAll(profile?.socialLinks ?? {});
        _notificationsEnabled = notif == null ? true : notif == 'true';
        _darkTheme = theme == null ? true : theme == 'true';
        _shareUsage = share == 'true';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _writeBool(String key, bool value) async {
    await _storage.write(key: key, value: value ? 'true' : 'false');
  }

  Future<void> _writeString(String key, String value) async {
    if (value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [UserAppBarActions()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Perfil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Nome de exibição',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: _displayName),
                      onChanged: (v) => _displayName = v,
                      onSubmitted: (v) async =>
                          await _writeString(_keyDisplayName, v.trim()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: _bio),
                      onChanged: (value) => _bio = value,
                    ),
                    const SizedBox(height: 12),
                    ...['instagram', 'tiktok', 'twitter', 'whatsapp'].map(
                      (network) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                network[0].toUpperCase() + network.substring(1),
                            prefixIcon: Icon(_socialIcon(network)),
                            border: const OutlineInputBorder(),
                          ),
                          controller: TextEditingController(
                            text: _socialLinks[network] ?? '',
                          ),
                          onChanged: (value) =>
                              _socialLinks[network] = value.trim(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Preferências',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Notificações'),
                      value: _notificationsEnabled,
                      onChanged: (v) async {
                        setState(() => _notificationsEnabled = v);
                        await _writeBool(_keyNotifications, v);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Tema escuro'),
                      subtitle: const Text(
                        'Alterna a preferência de tema (aplicativo pode precisar reiniciar)',
                      ),
                      value: _darkTheme,
                      onChanged: (v) async {
                        setState(() => _darkTheme = v);
                        await _writeBool(_keyDarkTheme, v);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Compartilhar dados de uso anônimos'),
                      value: _shareUsage,
                      onChanged: (v) async {
                        setState(() => _shareUsage = v);
                        await _writeBool(_keyShareUsage, v);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        // Persist display name locally
                        final trimmed = _displayName.trim();
                        await _writeString(_keyDisplayName, trimmed);

                        // If user is logged in, update profile (Auth + Firestore)
                        try {
                          final auth = context.read<AuthService>();
                          if (auth.currentUser != null) {
                            await AdminProfileService(storage: _storage)
                                .updateProfile(
                              displayName: trimmed,
                              bio: _bio.trim(),
                              socialLinks: Map<String, String>.from(
                                _socialLinks,
                              ),
                            );
                            // Reload current user in AuthService and notify auth providers so UI reflects new name immediately
                            try {
                              await auth.reloadCurrentUser();
                              // If a GoogleAuthProvider is registered, refresh it so listeners update
                              try {
                                final googleProvider =
                                    context.read<GoogleAuthProvider>();
                                await googleProvider.refresh();
                              } catch (_) {}
                            } catch (_) {}

                            AppFeedback.showSuccess(
                              context,
                              'Preferências salvas e perfil atualizado',
                            );
                            return;
                          }
                        } catch (e) {
                          // fall through to local save notification
                        }

                        AppFeedback.showSuccess(context, 'Preferências salvas');
                      },
                      child: const Text('Salvar alterações'),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Privacidade',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gerencie suas preferências de privacidade e notificações aqui.',
                    ),
                  ],
                ), // ListView
              ), // ConstrainedBox
            ), // Center
    );
  }
}

IconData _socialIcon(String network) {
  switch (network) {
    case 'instagram':
      return Icons.camera_alt_outlined;
    case 'tiktok':
      return Icons.music_note_outlined;
    case 'twitter':
      return Icons.alternate_email;
    case 'whatsapp':
      return Icons.chat_outlined;
    default:
      return Icons.link;
  }
}
