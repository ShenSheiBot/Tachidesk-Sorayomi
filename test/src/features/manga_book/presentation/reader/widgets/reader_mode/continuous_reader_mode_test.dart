import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_navigation.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_mode/continuous_reader_mode.dart';

void main() {
  group('ContinuousReaderMode.targetItemForStep', () {
    const middle = ReaderNavigationState(
      displayPageIndex: 2,
      atStart: false,
      atEnd: false,
      isBusy: false,
    );

    test('moves between page items', () {
      expect(
        ContinuousReaderMode.targetItemForStep(
          direction: ReadingDirection.forward,
          state: middle,
          pageCount: 5,
        ),
        4,
      );
      expect(
        ContinuousReaderMode.targetItemForStep(
          direction: ReadingDirection.backward,
          state: middle,
          pageCount: 5,
        ),
        2,
      );
    });

    test('returns from start sentinel to the first page', () {
      expect(
        ContinuousReaderMode.targetItemForStep(
          direction: ReadingDirection.forward,
          state: middle.copyWith(
            displayPageIndex: 0,
            atStart: true,
          ),
          pageCount: 5,
        ),
        1,
      );
    });

    test('returns from end sentinel to the last page', () {
      expect(
        ContinuousReaderMode.targetItemForStep(
          direction: ReadingDirection.backward,
          state: middle.copyWith(
            displayPageIndex: 4,
            atEnd: true,
          ),
          pageCount: 5,
        ),
        5,
      );
    });

    test('single-page sentinels return to the only page', () {
      final start = middle.copyWith(
        displayPageIndex: 0,
        atStart: true,
      );
      final end = middle.copyWith(
        displayPageIndex: 0,
        atEnd: true,
      );
      expect(
        ContinuousReaderMode.targetItemForStep(
          direction: ReadingDirection.forward,
          state: start,
          pageCount: 1,
        ),
        1,
      );
      expect(
        ContinuousReaderMode.targetItemForStep(
          direction: ReadingDirection.backward,
          state: end,
          pageCount: 1,
        ),
        1,
      );
    });
  });

  group('ContinuousReaderMode.projectNavigationState', () {
    test('last page item without end sentinel is not at end', () {
      final state = _project(
        pageCount: 3,
        positions: [
          _position(index: 3, leading: 0, trailing: 1),
        ],
      );

      expect(state.displayPageIndex, 2);
      expect(state.atEnd, isFalse);
    });

    test('fully visible end sentinel marks the end', () {
      final state = _project(
        pageCount: 3,
        positions: [
          _position(index: 3, leading: -0.2, trailing: 0.4),
          _position(index: 4, leading: 0.4, trailing: 1),
        ],
      );

      expect(state.displayPageIndex, 2);
      expect(state.atEnd, isTrue);
    });

    test('start sentinel must reach the viewport leading edge', () {
      final atStart = _project(
        pageCount: 3,
        positions: [
          _position(index: 0, leading: 0, trailing: 0.4),
          _position(index: 1, leading: 0.4, trailing: 1),
        ],
      );
      final beforeStart = _project(
        pageCount: 3,
        positions: [
          _position(index: 0, leading: -0.01, trailing: 0.4),
          _position(index: 1, leading: 0.4, trailing: 1),
        ],
      );

      expect(atStart.atStart, isTrue);
      expect(beforeStart.atStart, isFalse);
    });

    test('selects the page with the largest visible viewport area', () {
      final state = _project(
        pageCount: 3,
        positions: [
          _position(index: 1, leading: -0.3, trailing: 0.2),
          _position(index: 2, leading: 0.2, trailing: 0.9),
          _position(index: 3, leading: 0.9, trailing: 1.3),
        ],
      );

      expect(state.displayPageIndex, 1);
    });

    test('maps page item indexes around sentinels to display indexes', () {
      final firstPage = _project(
        pageCount: 3,
        positions: [
          _position(index: 0, leading: -0.4, trailing: 0),
          _position(index: 1, leading: 0, trailing: 1),
        ],
      );
      final lastPage = _project(
        pageCount: 3,
        positions: [
          _position(index: 3, leading: 0, trailing: 1),
          _position(index: 4, leading: 1, trailing: 1.5),
        ],
      );

      expect(firstPage.displayPageIndex, 0);
      expect(lastPage.displayPageIndex, 2);
      expect(lastPage.atEnd, isFalse);
    });

    test('keeps the previous display page when visible areas tie', () {
      const previous = ReaderNavigationState(
        displayPageIndex: 1,
        atStart: false,
        atEnd: false,
        isBusy: true,
      );

      final state = _project(
        pageCount: 3,
        previous: previous,
        positions: [
          _position(index: 1, leading: 0, trailing: 0.5),
          _position(index: 2, leading: 0.5, trailing: 1),
        ],
      );

      expect(state.displayPageIndex, 1);
      expect(state.isBusy, isTrue);
    });

    test('empty chapter resets boundaries and display index', () {
      const previous = ReaderNavigationState(
        displayPageIndex: 7,
        atStart: true,
        atEnd: true,
        isBusy: true,
      );

      final state = _project(
        pageCount: 0,
        previous: previous,
        positions: [
          _position(index: 0, leading: 0, trailing: 1),
        ],
      );

      expect(state.displayPageIndex, 0);
      expect(state.atStart, isTrue);
      expect(state.atEnd, isTrue);
      expect(state.isBusy, isTrue);
    });
  });
}

ReaderNavigationState _project({
  required int pageCount,
  required Iterable<ItemPosition> positions,
  ReaderNavigationState previous = const ReaderNavigationState(
    displayPageIndex: 0,
    atStart: false,
    atEnd: false,
    isBusy: false,
  ),
}) =>
    ContinuousReaderMode.projectNavigationState(
      positions: positions,
      pageCount: pageCount,
      previous: previous,
    );

ItemPosition _position({
  required int index,
  required double leading,
  required double trailing,
}) =>
    ItemPosition(
      index: index,
      itemLeadingEdge: leading,
      itemTrailingEdge: trailing,
    );
