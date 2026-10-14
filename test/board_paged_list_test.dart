import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bp2/models/board_page_result.dart';
import 'package:bp2/widgets/board/board_paged_list.dart';

void main() {
  testWidgets('empty board remains refreshable when another account posts', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardPagedList<int>(
            load: (_) async {
              reads++;
              return BoardPageResult(reads == 1 ? [] : [1], null, false);
            },
            itemBuilder: (_, i) => Text('item $i'),
            empty: const Center(child: Text('empty')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('empty'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('item 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('initial page does not recursively fetch the entire board', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardPagedList<int>(
            load: (_) async {
              reads++;
              return BoardPageResult(List.generate(20, (i) => i), null, true);
            },
            itemBuilder: (_, i) => SizedBox(height: 90, child: Text('item $i')),
            empty: const Text('empty'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 19'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2200));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed next page can retry while previously loaded content remains',
    (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardPagedList<int>(
              load: (_) async {
                reads++;
                if (reads == 2) throw StateError('offline');
                return BoardPageResult([reads], null, reads < 3);
              },
              itemBuilder: (_, i) => Text('item $i'),
              empty: const Text('empty'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('더 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('item 1'), findsOneWidget);
      await tester.tap(find.text('불러오지 못했어요. 다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('item 3'), findsOneWidget);
      expect(reads, 3);
    },
  );

  testWidgets('refresh rejects a stale response from the previous generation', (
    tester,
  ) async {
    final old = Completer<BoardPageResult<int>>();
    var reads = 0;
    Future<BoardPageResult<int>> load(dynamic _) async {
      reads++;
      return reads == 1 ? old.future : const BoardPageResult([2], null, false);
    }

    Widget app(int key) => MaterialApp(
      home: Scaffold(
        body: BoardPagedList<int>(
          refreshKey: key,
          load: load,
          itemBuilder: (_, i) => Text('item $i'),
          empty: const Text('empty'),
        ),
      ),
    );
    await tester.pumpWidget(app(0));
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();
    old.complete(const BoardPageResult([1], null, false));
    await tester.pumpAndSettle();
    expect(find.text('item 2'), findsOneWidget);
    expect(find.text('item 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
