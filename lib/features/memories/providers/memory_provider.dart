import 'package:flutter/foundation.dart';
import 'package:labomba_app/features/memories/models/memory.dart';
import 'package:labomba_app/features/memories/services/memory_service.dart';
import 'package:labomba_app/services/observability_service.dart';

class MemoryProvider with ChangeNotifier {
  final MemoryService _service;

  List<Memory> _memories = [];
  bool _isLoading = false;
  String? _error;

  MemoryProvider({MemoryService? service})
      : _service = service ?? InMemoryMemoryService();

  List<Memory> get memories => List.unmodifiable(_memories);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _memories = await _service.fetchMemories();
    } catch (e, s) {
      _error = e.toString();
      // Report to observability for debugging/telemetry
      try {
        await ObservabilityService.reportError(
          e,
          s,
          reason: 'MemoryProvider.load',
        );
      } catch (_) {}
      // Keep the last valid snapshot available while storage/network recovers.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addOrUpdate(Memory m) async {
    try {
      await _service.saveMemory(m);
      await load();
    } catch (e, s) {
      try {
        await ObservabilityService.reportError(
          e,
          s,
          reason: 'MemoryProvider.addOrUpdate',
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    try {
      await _service.deleteMemory(id);
      _memories.removeWhere((m) => m.id == id);
      notifyListeners();
    } catch (e, s) {
      try {
        await ObservabilityService.reportError(
          e,
          s,
          reason: 'MemoryProvider.remove',
        );
      } catch (_) {}
      rethrow;
    }
  }
}
