import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/memories/providers/memory_provider.dart';
import 'package:labomba_app/features/memories/services/storage_memory_service.dart';

import 'test_helpers/fake_storage.dart';

import 'package:labomba_app/features/memories/models/memory.dart';

void main() {
  group('MemoryProvider', () {
    late MemoryProvider provider;
    late FakeStorageService fakeStorage;

    setUp(() {
      fakeStorage = FakeStorageService();
      provider = MemoryProvider(
        service: StorageMemoryService(fakeStorage, key: 'prov_memories'),
      );
    });

    test(
      'load returns empty initially and addOrUpdate stores memory',
      () async {
        await provider.load();
        expect(provider.memories, isEmpty);

        final m = Memory(
          id: 'a1',
          title: 'Test',
          description: 'x',
          imageUrls: [],
          createdAt: DateTime.now(),
        );
        await provider.addOrUpdate(m);
        expect(provider.memories.length, 1);
        expect(provider.memories.first.id, 'a1');

        await provider.remove('a1');
        expect(provider.memories, isEmpty);
      },
    );
  });
}
