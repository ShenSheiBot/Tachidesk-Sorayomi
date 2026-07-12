import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_navigation.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_navigation_layout/reader_navigation_layout.dart';

void main() {
  Future<void> pumpEdgeLayout(
    WidgetTester tester, {
    required ReaderMode mode,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    bool invertTap = false,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: SizedBox.expand(
            child: ReaderNavigationLayoutWidget(
              navigationLayout: ReaderNavigationLayout.edge,
              navigation: ResolvedReaderNavigation.fromMode(mode),
              invertTap: invertTap,
              onPrevious: onPrevious,
              onNext: onNext,
            ),
          ),
        ),
      );

  testWidgets('Edge layout maps physical sides in LTR', (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;
    await pumpEdgeLayout(
      tester,
      mode: ReaderMode.singleHorizontalLTR,
      onPrevious: () => previousCalls++,
      onNext: () => nextCalls++,
    );

    await tester.tapAt(const Offset(40, 200));
    await tester.tapAt(const Offset(760, 200));

    expect(previousCalls, 1);
    expect(nextCalls, 1);
  });

  testWidgets('Edge layout maps physical sides in RTL', (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;
    await pumpEdgeLayout(
      tester,
      mode: ReaderMode.singleHorizontalRTL,
      onPrevious: () => previousCalls++,
      onNext: () => nextCalls++,
    );

    await tester.tapAt(const Offset(40, 200));
    await tester.tapAt(const Offset(760, 200));

    expect(nextCalls, 1);
    expect(previousCalls, 1);
  });
}
