import 'dart:async';

import 'package:labomba_app/features/memories/models/memory.dart';

/// Abstract MemoryService: fetch/save/delete memories. Implementations may
/// use local storage or remote APIs.
abstract class MemoryService {
  Future<List<Memory>> fetchMemories();
  Future<Memory?> getMemory(String id);
  Future<void> saveMemory(Memory memory);
  Future<void> deleteMemory(String id);
}

/// A simple in-memory implementation useful for initial development and tests.
class InMemoryMemoryService implements MemoryService {
  final List<Memory> _store = <Memory>[];

  @override
  Future<List<Memory>> fetchMemories() async {
    // simulate network/storage latency
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<Memory>.unmodifiable(_store);
  }

  @override
  Future<Memory?> getMemory(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final idx = _store.indexWhere((m) => m.id == id);
    if (idx < 0) return null;
    return _store[idx];
  }

  @override
  Future<void> saveMemory(Memory memory) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final idx = _store.indexWhere((m) => m.id == memory.id);
    if (idx >= 0) {
      _store[idx] = memory;
    } else {
      _store.add(memory);
    }
  }

  @override
  Future<void> deleteMemory(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _store.removeWhere((m) => m.id == id);
  }
}
