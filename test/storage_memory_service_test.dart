import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/memories/services/storage_memory_service.dart';

import 'test_helpers/fake_storage.dart';

import 'package:labomba_app/features/memories/models/memory.dart';

void main() {
  group('StorageMemoryService', () {
    late FakeStorageService fakeStorage;
    late StorageMemoryService svc;

    setUp(() {
      fakeStorage = FakeStorageService();
      svc = StorageMemoryService(fakeStorage, key: 'test_memories');
    });

    test('starts empty and can save and fetch memories', () async {
      final list0 = await svc.fetchMemories();
      expect(list0, isEmpty);

      final m = Memory(
        id: '1',
        title: 'Olá',
        description: 'desc',
        imageUrls: [],
        createdAt: DateTime.now(),
      );
      await svc.saveMemory(m);

      final fetched = await svc.fetchMemories();
      expect(fetched.length, 1);
      expect(fetched.first.id, '1');

      final byId = await svc.getMemory('1');
      expect(byId, isNotNull);
      expect(byId!.title, 'Olá');

      await svc.deleteMemory('1');
      final afterDel = await svc.fetchMemories();
      expect(afterDel, isEmpty);
    });
  });
}
