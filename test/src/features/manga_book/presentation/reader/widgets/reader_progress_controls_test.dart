import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_navigation.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_progress_controls.dart';

void main() {
  Future<void> pumpControls(
    WidgetTester tester,
    ReaderMode mode, {
    VoidCallback? onPreviousChapter,
    VoidCallback? onNextChapter,
    TextDirection ambientDirection = TextDirection.ltr,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: ambientDirection,
              child: SizedBox(
                width: 600,
                child: ReaderProgressControls(
                  navigation: ResolvedReaderNavigation.fromMode(mode),
                  currentPageIndex: 1,
                  pageCount: 10,
                  onPageChanged: (_) {},
                  onPreviousChapter: onPreviousChapter ?? () {},
                  onNextChapter: onNextChapter ?? () {},
                  previousChapterTooltip: 'Previous chapter',
                  nextChapterTooltip: 'Next chapter',
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('LTR puts previous on the left and next on the right',
      (tester) async {
    await pumpControls(tester, ReaderMode.singleHorizontalLTR);

    final previous = tester.getCenter(
      find.byKey(ReaderProgressControls.previousChapterButtonKey),
    );
    final next = tester.getCenter(
      find.byKey(ReaderProgressControls.nextChapterButtonKey),
    );
    expect(previous.dx, lessThan(next.dx));
    expect(tester.getCenter(find.text('2')).dx,
        lessThan(tester.getCenter(find.text('10')).dx));
  });

  testWidgets('RTL puts next on the left and previous on the right',
      (tester) async {
    await pumpControls(tester, ReaderMode.singleHorizontalRTL);

    final previous = tester.getCenter(
      find.byKey(ReaderProgressControls.previousChapterButtonKey),
    );
    final next = tester.getCenter(
      find.byKey(ReaderProgressControls.nextChapterButtonKey),
    );
    expect(next.dx, lessThan(previous.dx));
    expect(tester.getCenter(find.text('10')).dx,
        lessThan(tester.getCenter(find.text('2')).dx));
  });

  testWidgets('chapter controls keep their semantic callbacks in RTL',
      (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;
    await pumpControls(
      tester,
      ReaderMode.singleHorizontalRTL,
      onPreviousChapter: () => previousCalls++,
      onNextChapter: () => nextCalls++,
    );

    await tester.tap(
      find.byKey(ReaderProgressControls.previousChapterButtonKey),
    );
    await tester.tap(find.byKey(ReaderProgressControls.nextChapterButtonKey));

    expect(previousCalls, 1);
    expect(nextCalls, 1);
  });

  testWidgets('reader direction is independent from ambient UI direction',
      (tester) async {
    await pumpControls(
      tester,
      ReaderMode.singleHorizontalLTR,
      ambientDirection: TextDirection.rtl,
    );
    final ltrPrevious = tester.getCenter(
      find.byKey(ReaderProgressControls.previousChapterButtonKey),
    );
    final ltrNext = tester.getCenter(
      find.byKey(ReaderProgressControls.nextChapterButtonKey),
    );
    expect(ltrPrevious.dx, lessThan(ltrNext.dx));

    await pumpControls(
      tester,
      ReaderMode.singleHorizontalRTL,
      ambientDirection: TextDirection.rtl,
    );
    final rtlPrevious = tester.getCenter(
      find.byKey(ReaderProgressControls.previousChapterButtonKey),
    );
    final rtlNext = tester.getCenter(
      find.byKey(ReaderProgressControls.nextChapterButtonKey),
    );
    expect(rtlNext.dx, lessThan(rtlPrevious.dx));
  });
}
