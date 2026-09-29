import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_navigation.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_page_scroll_listener.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_wrapper.dart';

Future<void> wheel(WidgetTester tester, double delta,
    {Offset position = const Offset(400, 300)}) async {
  await tester.sendEventToBinding(PointerScrollEvent(
    kind: PointerDeviceKind.mouse,
    position: position,
    scrollDelta: Offset(0, delta),
  ));
  await tester.pump();
}

void main() {
  testWidgets('rapid wheel ticks are not dropped during page animation',
      (tester) async {
    final coordinator = ReaderNavigationCoordinator();
    final state = ValueNotifier(const ReaderNavigationState(
      displayPageIndex: 0,
      atStart: true,
      atEnd: false,
      isBusy: false,
    ));
    addTearDown(coordinator.dispose);
    addTearDown(state.dispose);
    final firstAnimation = Completer<void>();
    var pages = 0;
    final bindings = ReaderNavigationBindings(
      state: state,
      stepPage: (_) async {
        pages++;
        if (pages == 1) await firstAnimation.future;
        return ReaderPageStepResult.moved;
      },
      jumpToPage: (_) async {},
      changeChapter: (_) => false,
    );
    await tester.pumpWidget(MaterialApp(
        home: ReaderPageScrollListener(
      onCommand: (command) =>
          unawaited(coordinator.dispatch(command, bindings)),
      child: const SizedBox.expand(),
    )));
    for (var i = 0; i < 12; i++) {
      await wheel(tester, 120);
    }
    firstAnimation.complete();
    await tester.pump();
    expect(pages, 12);
  });

  for (final axis in Axis.values) {
    testWidgets(
        '$axis: nested wheel listeners beat pixel scrolling and fire once',
        (tester) async {
      final controller = PageController(initialPage: 1);
      addTearDown(controller.dispose);
      final directions = <ReadingDirection>[];
      void dispatch(ReaderCommand command) {
        final direction = (command as StepReaderPage).direction;
        directions.add(direction);
        controller.jumpToPage(controller.page!.round() +
            (direction == ReadingDirection.forward ? 1 : -1));
      }

      await tester.pumpWidget(MaterialApp(
          home: ReaderPageScrollListener(
        onCommand: dispatch,
        child: PageView.builder(
          controller: controller,
          scrollDirection: axis,
          itemCount: 5,
          itemBuilder: (_, __) => ReaderPageScrollListener(
            onCommand: dispatch,
            child: const SizedBox.expand(),
          ),
        ),
      )));
      await wheel(tester, 1200);
      expect(controller.page, 2);
      await wheel(tester, -1);
      expect(controller.page, 1);
      expect(directions, [ReadingDirection.forward, ReadingDirection.backward]);
    });
  }

  for (final mode in [
    ReaderMode.singleHorizontalLTR,
    ReaderMode.singleHorizontalRTL,
    ReaderMode.singleVertical,
  ]) {
    for (final layout in [
      ReaderNavigationLayout.disabled,
      ReaderNavigationLayout.edge,
    ]) {
      testWidgets('$mode $layout: one command per wheel event', (tester) async {
        final commands = <ReaderCommand>[];
        await tester.pumpWidget(MaterialApp(
          home: ReaderView(
            toggleVisibility: () {},
            navigation: ResolvedReaderNavigation.fromMode(mode),
            mangaReaderPadding: 0,
            mangaReaderMagnifierSize: 1,
            onCommand: commands.add,
            mangaReaderNavigationLayout: layout,
            invertTap: true,
            readerSwipeChapterToggle: false,
            lastPageSwipeEnabled: true,
            child:
                const ColoredBox(color: Colors.white, child: SizedBox.expand()),
          ),
        ));
        for (final position in [
          const Offset(400, 300),
          const Offset(40, 300)
        ]) {
          await wheel(tester, 1, position: position);
          await wheel(tester, 1200, position: position);
          await wheel(tester, -120, position: position);
        }
        expect(commands.whereType<StepReaderPage>().map((c) => c.direction), [
          ReadingDirection.forward,
          ReadingDirection.forward,
          ReadingDirection.backward,
          ReadingDirection.forward,
          ReadingDirection.forward,
          ReadingDirection.backward,
        ]);
      });
    }
  }
}
