import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:labomba_app/features/memories/memories_module.dart';

import 'test_helpers/fake_storage.dart';

import 'package:labomba_app/features/memories/services/storage_memory_service.dart';

void main() {
  testWidgets('MemoriesListPage and MemoryEditorPage render and interact', (
    WidgetTester tester,
  ) async {
    final fakeStorage = FakeStorageService();
    final storageSvc = StorageMemoryService(fakeStorage, key: 'ui_memories');
    final provider = MemoryProvider(service: storageSvc);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MemoryProvider>.value(value: provider),
        ],
        child: MaterialApp(home: MemoriesListPage()),
      ),
    );

    // ensure page renders
    await tester.pumpAndSettle();
    expect(find.text('Memórias'), findsOneWidget);

    // FAB opens editor
    final fab = find.byIcon(Icons.add);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Editor shows title field and emoji/gif/sticker icons
    expect(find.text('Nova Memória'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_emotions), findsOneWidget);
    expect(find.byIcon(Icons.gif), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2), findsOneWidget);
  });
}
