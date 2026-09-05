import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../widgets/app_feedback.dart';

class PrivacyDataManagementPage extends StatefulWidget {
  const PrivacyDataManagementPage({super.key});

  @override
  State<PrivacyDataManagementPage> createState() =>
      _PrivacyDataManagementPageState();
}

class _PrivacyDataManagementPageState extends State<PrivacyDataManagementPage> {
  static const _memoriesKey = 'memories_store';
  late final StorageService _storage;
  bool _loading = true;
  int _storedBytes = 0;
  int _offlineMemories = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = context.read<StorageService>();
    _loadStorageStatus();
  }

  Future<void> _loadStorageStatus() async {
    final memories = await _storage.read(key: _memoriesKey);
    var count = 0;
    if (memories != null && memories.isNotEmpty) {
      final decoded = jsonDecode(memories);
      if (decoded is List) count = decoded.length;
    }
    if (!mounted) return;
    setState(() {
      _storedBytes = memories == null ? 0 : utf8.encode(memories).length;
      _offlineMemories = count;
      _loading = false;
    });
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _clearCache() async {
    final confirmed = await _confirm(
      title: 'Limpar cache?',
      message:
          'Imagens em cache serão removidas. Suas memórias salvas não serão apagadas.',
      action: 'Limpar cache',
    );
    if (!confirmed) return;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (!mounted) return;
    AppFeedback.showSuccess(context, 'Cache de imagens limpo.');
  }

  Future<void> _deleteLocalData() async {
    final confirmed = await _confirm(
      title: 'Excluir dados locais?',
      message:
          'Todas as preferências, memórias offline e credenciais armazenadas neste dispositivo serão removidas. Esta ação não pode ser desfeita.',
      action: 'Excluir dados',
    );
    if (!confirmed) return;
    await _storage.deleteAll();
    if (!mounted) return;
    setState(() {
      _storedBytes = 0;
      _offlineMemories = 0;
    });
    AppFeedback.showSuccess(context, 'Dados locais excluídos.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dados e privacidade')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Armazenamento local',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.storage_outlined),
                        title: const Text('Dados armazenados'),
                        subtitle: Text(
                          '$_storedBytes bytes de memórias offline',
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('Memórias offline'),
                        subtitle: Text(
                          '$_offlineMemories memórias salvas neste dispositivo',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Limpar cache de imagens'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _deleteLocalData,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Excluir dados locais sensíveis'),
                ),
              ],
            ),
    );
  }
}
