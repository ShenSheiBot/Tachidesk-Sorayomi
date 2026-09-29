import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_interactive_viewer.dart';

import 'reader_mouse_wheel_test.dart' show wheel;

void main() {
  testWidgets(
      'wheel scrolls both ways without scaling; touch pinch still works',
      (tester) async {
    final scroll = ScrollController(initialScrollOffset: 300);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ReaderInteractiveViewer(
        child: ListView(
          controller: scroll,
          children: const [
            SizedBox(height: 3000, child: ColoredBox(color: Colors.white))
          ],
        ),
      ),
    ));
    double scale() => tester
        .widget<Transform>(find
            .descendant(
              of: find.byType(InteractiveViewer),
              matching: find.byType(Transform),
            )
            .first)
        .transform
        .getMaxScaleOnAxis();
    await wheel(tester, 100);
    expect(scroll.offset, 400);
    expect(scale(), 1);
    await wheel(tester, -100);
    expect(scroll.offset, 300);
    expect(scale(), 1);
    scroll.jumpTo(0);
    await wheel(tester, -100);
    expect(scroll.offset, 0);
    expect(scale(), 1);

    final left = await tester.startGesture(const Offset(300, 300), pointer: 1);
    final right = await tester.startGesture(const Offset(500, 300), pointer: 2);
    await tester.pump();
    await left.moveTo(const Offset(250, 300));
    await right.moveTo(const Offset(550, 300));
    await tester.pump();
    await left.moveTo(const Offset(200, 300));
    await right.moveTo(const Offset(600, 300));
    await tester.pump();
    expect(scale(), greaterThan(1));
    await left.up();
    await right.up();
  });
}
