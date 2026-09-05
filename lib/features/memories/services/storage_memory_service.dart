import 'dart:convert';

import 'package:labomba_app/features/memories/models/memory.dart';
import 'package:labomba_app/features/memories/services/memory_service.dart';
import 'package:labomba_app/services/storage_service.dart';

class StorageMemoryService implements MemoryService {
  final StorageService _storage;
  final String _key;
  String get _backupKey => '${_key}_backup';

  StorageMemoryService(this._storage, {String key = 'memories_store'})
      : _key = key;

  Future<List<Memory>> _readAll() async {
    final raw = await _storage.read(key: _key);
    try {
      final memories = _decode(raw);
      memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return memories;
    } catch (_) {
      final backup = await _storage.read(key: _backupKey);
      final memories = _decode(backup);
      memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return memories;
    }
  }

  Future<void> _writeAll(List<Memory> all) async {
    final encoded = jsonEncode(all.map((m) => m.toJson()).toList());
    final previous = await _storage.read(key: _key);
    if (previous != null && previous.isNotEmpty) {
      await _storage.write(key: _backupKey, value: previous);
    }
    await _storage.write(key: _key, value: encoded);
  }

  List<Memory> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Invalid memories cache format');
    }
    return decoded
        .map(
          (entry) => Memory.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
  }

  @override
  Future<void> deleteMemory(String id) async {
    final all = await _readAll();
    final remaining = all.where((m) => m.id != id).toList();
    await _writeAll(remaining);
  }

  @override
  Future<Memory?> getMemory(String id) async {
    final all = await _readAll();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx < 0) return null;
    return all[idx];
  }

  @override
  Future<List<Memory>> fetchMemories() async {
    return await _readAll();
  }

  @override
  Future<void> saveMemory(Memory memory) async {
    final all = await _readAll();
    final idx = all.indexWhere((m) => m.id == memory.id);
    if (idx >= 0) {
      all[idx] = memory;
    } else {
      all.add(memory);
    }
    await _writeAll(all);
  }
}
