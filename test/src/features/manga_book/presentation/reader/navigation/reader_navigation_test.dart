import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_navigation.dart';

void main() {
  group('ResolvedReaderNavigation', () {
    test('resolveMode uses each explicit manga reader mode', () {
      for (final mode in ReaderMode.values.where(
        (mode) => mode != ReaderMode.defaultReader,
      )) {
        expect(
          ResolvedReaderNavigation.resolveMode(
            mangaReaderMode: mode,
            defaultReaderMode: ReaderMode.singleVertical,
          ),
          mode,
          reason: '$mode should override the default reader mode',
        );
      }
    });

    test('resolveMode resolves null and default manga modes from defaults', () {
      for (final mangaMode in <ReaderMode?>[
        null,
        ReaderMode.defaultReader,
      ]) {
        for (final defaultMode in <ReaderMode?>[
          null,
          ...ReaderMode.values,
        ]) {
          final expected =
              defaultMode == null || defaultMode == ReaderMode.defaultReader
                  ? ReaderMode.webtoon
                  : defaultMode;

          expect(
            ResolvedReaderNavigation.resolveMode(
              mangaReaderMode: mangaMode,
              defaultReaderMode: defaultMode,
            ),
            expected,
            reason: 'manga=$mangaMode, default=$defaultMode',
          );
        }
      }
    });

    for (final expectation in _modeExpectations) {
      test('${expectation.inputMode} exposes consistent navigation values', () {
        final navigation = ResolvedReaderNavigation.fromMode(
          expectation.inputMode,
        );

        expect(navigation.mode, expectation.resolvedMode);
        expect(navigation.axis, expectation.axis);
        expect(navigation.isHorizontalRtl, expectation.isHorizontalRtl);
        expect(navigation.pageViewReverse, expectation.isHorizontalRtl);
        expect(navigation.sliderInverted, expectation.isHorizontalRtl);
        expect(
          navigation.controlTextDirection,
          expectation.isHorizontalRtl ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          navigation.forwardControlDirection,
          expectation.forwardControlDirection,
        );
        expect(
          navigation.backwardControlDirection,
          expectation.backwardControlDirection,
        );
        expect(
          navigation.directionForControl(
            expectation.forwardControlDirection,
          ),
          ReadingDirection.forward,
        );
        expect(
          navigation.directionForControl(
            expectation.backwardControlDirection,
          ),
          ReadingDirection.backward,
        );

        final forwardTransition = navigation.chapterTransition(
          ReadingDirection.forward,
        );
        expect(
          forwardTransition.entryFrom,
          expectation.forwardControlDirection,
        );
        expect(forwardTransition.isVertical, expectation.axis == Axis.vertical);
        expect(
          forwardTransition.fromNegativeDirection,
          expectation.forwardFromNegativeDirection,
        );

        final backwardTransition = navigation.chapterTransition(
          ReadingDirection.backward,
        );
        expect(
          backwardTransition.entryFrom,
          expectation.backwardControlDirection,
        );
        expect(
          backwardTransition.isVertical,
          expectation.axis == Axis.vertical,
        );
        expect(
          backwardTransition.fromNegativeDirection,
          expectation.backwardFromNegativeDirection,
        );

        final offAxisDirections = expectation.axis == Axis.horizontal
            ? const [AxisDirection.up, AxisDirection.down]
            : const [AxisDirection.left, AxisDirection.right];
        for (final direction in offAxisDirections) {
          expect(
            () => navigation.directionForControl(direction),
            throwsA(
              isA<ArgumentError>()
                  .having((error) => error.name, 'name', 'direction')
                  .having((error) => error.invalidValue, 'value', direction),
            ),
          );
        }
      });
    }
  });

  group('ReaderChapterTransition', () {
    test('classifies every entry direction', () {
      const expectations = {
        AxisDirection.up: (isVertical: true, fromNegative: true),
        AxisDirection.right: (isVertical: false, fromNegative: false),
        AxisDirection.down: (isVertical: true, fromNegative: false),
        AxisDirection.left: (isVertical: false, fromNegative: true),
      };

      for (final entry in expectations.entries) {
        final transition = ReaderChapterTransition(entryFrom: entry.key);
        expect(transition.isVertical, entry.value.isVertical);
        expect(
          transition.fromNegativeDirection,
          entry.value.fromNegative,
        );
      }
    });
  });

  group('ReaderNavigationState', () {
    test('copyWith replaces selected state fields', () {
      const initial = ReaderNavigationState(
        displayPageIndex: 2,
        atStart: true,
        atEnd: false,
        isBusy: true,
      );

      final updated = initial.copyWith(
        displayPageIndex: 8,
        atStart: false,
        atEnd: true,
        isBusy: false,
      );

      expect(updated.displayPageIndex, 8);
      expect(updated.atStart, isFalse);
      expect(updated.atEnd, isTrue);
      expect(updated.isBusy, isFalse);

      final unchanged = initial.copyWith();
      expect(unchanged.displayPageIndex, initial.displayPageIndex);
      expect(unchanged.atStart, initial.atStart);
      expect(unchanged.atEnd, initial.atEnd);
      expect(unchanged.isBusy, initial.isBusy);
    });
  });

  group('ReaderNavigationCoordinator', () {
    test('moves within a page without changing chapter', () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState();
      final steppedDirections = <ReadingDirection>[];
      var chapterChanges = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (direction) async {
          steppedDirections.add(direction);
          return ReaderPageStepResult.moved;
        },
        jumpToPage: (_) async {},
        changeChapter: (_) {
          chapterChanges++;
          return true;
        },
      );

      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );

      expect(steppedDirections, [ReadingDirection.forward]);
      expect(chapterChanges, 0);
      expect(coordinator.isExecuting, isFalse);
      expect(coordinator.chapterTransitionStarted, isFalse);
    });

    test('changes chapter directly without requiring a page boundary',
        () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(isBusy: true);
      final chapterDirections = <ReadingDirection>[];
      var stepCalls = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async {
          stepCalls++;
          return ReaderPageStepResult.moved;
        },
        jumpToPage: (_) async {},
        changeChapter: (direction) {
          chapterDirections.add(direction);
          return true;
        },
      );

      await coordinator.dispatch(
        const ChangeReaderChapter(ReadingDirection.backward),
        bindings,
      );
      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );

      expect(chapterDirections, [ReadingDirection.backward]);
      expect(stepCalls, 0, reason: 'commands after a transition are ignored');
      expect(coordinator.chapterTransitionStarted, isTrue);
    });

    test('waits for chapter preparation before locking the transition',
        () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState();
      final prepared = Completer<bool>();
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async => ReaderPageStepResult.moved,
        jumpToPage: (_) async {},
        changeChapter: (_) => prepared.future,
      );

      final dispatch = coordinator.dispatch(
        const ChangeReaderChapter(ReadingDirection.forward),
        bindings,
      );
      expect(coordinator.isExecuting, isTrue);
      expect(coordinator.chapterTransitionStarted, isFalse);

      prepared.complete(true);
      await dispatch;

      expect(coordinator.chapterTransitionStarted, isTrue);
      expect(coordinator.isExecuting, isFalse);
    });

    for (final direction in ReadingDirection.values) {
      test('changes chapter at the confirmed $direction boundary', () async {
        final coordinator = ReaderNavigationCoordinator();
        final state = _navigationState(
          atStart: direction == ReadingDirection.backward,
          atEnd: direction == ReadingDirection.forward,
        );
        final chapterDirections = <ReadingDirection>[];
        var stepCalls = 0;
        final bindings = ReaderNavigationBindings(
          state: state,
          stepPage: (_) async {
            stepCalls++;
            return ReaderPageStepResult.moved;
          },
          jumpToPage: (_) async {},
          changeChapter: (direction) {
            chapterDirections.add(direction);
            return true;
          },
        );

        await coordinator.dispatch(StepReaderPage(direction), bindings);

        expect(stepCalls, 0, reason: 'a confirmed boundary skips page motion');
        expect(chapterDirections, [direction]);
        expect(coordinator.chapterTransitionStarted, isTrue);
        expect(coordinator.isExecuting, isFalse);
      });
    }

    test('changes chapter when a page step reaches a confirmed boundary',
        () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState();
      final chapterDirections = <ReadingDirection>[];
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async {
          state.value = state.value.copyWith(atEnd: true);
          return ReaderPageStepResult.atBoundary;
        },
        jumpToPage: (_) async {},
        changeChapter: (direction) {
          chapterDirections.add(direction);
          return true;
        },
      );

      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );

      expect(chapterDirections, [ReadingDirection.forward]);
      expect(coordinator.chapterTransitionStarted, isTrue);
    });

    test('does not cross chapter when display index is last but atEnd is false',
        () async {
      const lastDisplayIndex = 9;
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(displayPageIndex: lastDisplayIndex);
      var stepCalls = 0;
      var chapterChanges = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async {
          stepCalls++;
          return ReaderPageStepResult.atBoundary;
        },
        jumpToPage: (_) async {},
        changeChapter: (_) {
          chapterChanges++;
          return true;
        },
      );

      expect(state.value.displayPageIndex, lastDisplayIndex);
      expect(state.value.atEnd, isFalse);
      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );

      expect(stepCalls, 1);
      expect(chapterChanges, 0);
      expect(coordinator.chapterTransitionStarted, isFalse);
    });

    test('does not change chapter when boundary behavior is stop', () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(atEnd: true);
      var stepCalls = 0;
      var chapterChanges = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async {
          stepCalls++;
          return ReaderPageStepResult.atBoundary;
        },
        jumpToPage: (_) async {},
        changeChapter: (_) {
          chapterChanges++;
          return true;
        },
      );

      await coordinator.dispatch(
        const StepReaderPage(
          ReadingDirection.forward,
          atBoundary: ReaderBoundaryBehavior.stop,
        ),
        bindings,
      );

      expect(stepCalls, 0);
      expect(chapterChanges, 0);
      expect(coordinator.chapterTransitionStarted, isFalse);
    });

    test('does not change chapter when a page step is unavailable', () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState();
      var chapterChanges = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async => ReaderPageStepResult.unavailable,
        jumpToPage: (_) async {},
        changeChapter: (_) {
          chapterChanges++;
          return true;
        },
      );

      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.backward),
        bindings,
      );

      expect(chapterChanges, 0);
      expect(coordinator.chapterTransitionStarted, isFalse);
    });

    test('does not lock when no adjacent chapter exists', () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(atEnd: true);
      final chapterDirections = <ReadingDirection>[];
      final steppedDirections = <ReadingDirection>[];
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (direction) async {
          steppedDirections.add(direction);
          return ReaderPageStepResult.moved;
        },
        jumpToPage: (_) async {},
        changeChapter: (direction) {
          chapterDirections.add(direction);
          return false;
        },
      );

      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );
      expect(coordinator.chapterTransitionStarted, isFalse);

      state.value = state.value.copyWith(atEnd: false);
      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );

      expect(chapterDirections, [ReadingDirection.forward]);
      expect(steppedDirections, [ReadingDirection.forward]);
      expect(coordinator.isExecuting, isFalse);
      expect(coordinator.chapterTransitionStarted, isFalse);
    });

    test('rapid concurrent commands start at most one chapter transition',
        () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState();
      final firstStep = Completer<void>();
      var stepCalls = 0;
      var chapterChanges = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async {
          stepCalls++;
          await firstStep.future;
          state.value = state.value.copyWith(atEnd: true);
          return ReaderPageStepResult.atBoundary;
        },
        jumpToPage: (_) async {},
        changeChapter: (_) {
          chapterChanges++;
          return true;
        },
      );

      final firstDispatch = coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );
      expect(coordinator.isExecuting, isTrue);

      final queuedDispatches = [
        for (var index = 0; index < 10; index++)
          coordinator.dispatch(
            const StepReaderPage(ReadingDirection.forward),
            bindings,
          ),
      ];
      await Future.wait(queuedDispatches);
      firstStep.complete();
      await firstDispatch;

      expect(stepCalls, 1);
      expect(chapterChanges, 1);
      expect(coordinator.chapterTransitionStarted, isTrue);
      expect(coordinator.isExecuting, isFalse);
    });

    test('busy to idle executes the waiting page command exactly once',
        () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(isBusy: true);
      final steppedDirections = <ReadingDirection>[];
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (direction) async {
          steppedDirections.add(direction);
          return ReaderPageStepResult.moved;
        },
        jumpToPage: (_) async {},
        changeChapter: (_) => true,
      );

      final firstDispatch = coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );
      expect(coordinator.isExecuting, isTrue);
      expect(steppedDirections, isEmpty);

      state.value = state.value.copyWith(isBusy: false);
      await firstDispatch;

      expect(steppedDirections, [ReadingDirection.forward]);
      expect(coordinator.isExecuting, isFalse);
    });

    test('while busy preserves distinct page commands in order', () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(isBusy: true);
      final steppedDirections = <ReadingDirection>[];
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (direction) async {
          steppedDirections.add(direction);
          return ReaderPageStepResult.moved;
        },
        jumpToPage: (_) async {},
        changeChapter: (_) => true,
      );

      final firstDispatch = coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );

      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );
      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.backward),
        bindings,
      );
      expect(steppedDirections, isEmpty);

      state.value = state.value.copyWith(isBusy: false);
      await firstDispatch;

      expect(steppedDirections, [
        ReadingDirection.forward,
        ReadingDirection.forward,
        ReadingDirection.backward,
      ]);
      expect(coordinator.isExecuting, isFalse);
    });

    test('chapter change cannot be overwritten by later page commands',
        () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(isBusy: true);
      final chapterDirections = <ReadingDirection>[];
      final steppedDirections = <ReadingDirection>[];
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (direction) async {
          steppedDirections.add(direction);
          return ReaderPageStepResult.moved;
        },
        jumpToPage: (_) async {},
        changeChapter: (direction) {
          chapterDirections.add(direction);
          return true;
        },
      );

      final firstDispatch = coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );
      await coordinator.dispatch(
        const ChangeReaderChapter(ReadingDirection.forward),
        bindings,
      );
      await coordinator.dispatch(
        const StepReaderPage(ReadingDirection.backward),
        bindings,
      );

      state.value = state.value.copyWith(isBusy: false);
      await firstDispatch;

      expect(steppedDirections, isEmpty);
      expect(chapterDirections, [ReadingDirection.forward]);
      expect(coordinator.chapterTransitionStarted, isTrue);
    });

    test('jumps to the requested page', () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(isBusy: true);
      final jumpedIndexes = <int>[];
      var stepCalls = 0;
      var chapterChanges = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async {
          stepCalls++;
          return ReaderPageStepResult.moved;
        },
        jumpToPage: (index) async {
          jumpedIndexes.add(index);
        },
        changeChapter: (_) {
          chapterChanges++;
          return true;
        },
      );

      await coordinator.dispatch(const JumpToReaderPage(17), bindings);

      expect(jumpedIndexes, [17]);
      expect(stepCalls, 0);
      expect(chapterChanges, 0);
      expect(coordinator.isExecuting, isFalse);
    });

    test('dispose cancels an idle wait and ignores later commands', () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState(isBusy: true);
      var stepCalls = 0;
      var jumpCalls = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) async {
          stepCalls++;
          return ReaderPageStepResult.moved;
        },
        jumpToPage: (_) async {
          jumpCalls++;
        },
        changeChapter: (_) => true,
      );

      final waitingDispatch = coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );
      expect(coordinator.isExecuting, isTrue);

      coordinator.dispose();
      coordinator.dispose();
      await waitingDispatch;
      await coordinator.dispatch(const JumpToReaderPage(4), bindings);

      expect(stepCalls, 0);
      expect(jumpCalls, 0);
      expect(coordinator.isExecuting, isFalse);
      expect(coordinator.chapterTransitionStarted, isFalse);
    });

    test('dispose ignores completion of an in-flight page step', () async {
      final coordinator = ReaderNavigationCoordinator();
      final state = _navigationState();
      final stepResult = Completer<ReaderPageStepResult>();
      var chapterChanges = 0;
      final bindings = ReaderNavigationBindings(
        state: state,
        stepPage: (_) => stepResult.future,
        jumpToPage: (_) async {},
        changeChapter: (_) {
          chapterChanges++;
          return true;
        },
      );

      final dispatch = coordinator.dispatch(
        const StepReaderPage(ReadingDirection.forward),
        bindings,
      );
      coordinator.dispose();
      stepResult.complete(ReaderPageStepResult.atBoundary);
      await dispatch;

      expect(chapterChanges, 0);
      expect(coordinator.chapterTransitionStarted, isFalse);
      expect(coordinator.isExecuting, isFalse);
    });
  });
}

ValueNotifier<ReaderNavigationState> _navigationState({
  int displayPageIndex = 0,
  bool atStart = false,
  bool atEnd = false,
  bool isBusy = false,
}) =>
    ValueNotifier(
      ReaderNavigationState(
        displayPageIndex: displayPageIndex,
        atStart: atStart,
        atEnd: atEnd,
        isBusy: isBusy,
      ),
    );

final class _ModeExpectation {
  const _ModeExpectation({
    required this.inputMode,
    required this.resolvedMode,
    required this.axis,
    required this.isHorizontalRtl,
    required this.forwardControlDirection,
    required this.backwardControlDirection,
    required this.forwardFromNegativeDirection,
    required this.backwardFromNegativeDirection,
  });

  final ReaderMode inputMode;
  final ReaderMode resolvedMode;
  final Axis axis;
  final bool isHorizontalRtl;
  final AxisDirection forwardControlDirection;
  final AxisDirection backwardControlDirection;
  final bool forwardFromNegativeDirection;
  final bool backwardFromNegativeDirection;
}

const _modeExpectations = [
  _ModeExpectation(
    inputMode: ReaderMode.defaultReader,
    resolvedMode: ReaderMode.webtoon,
    axis: Axis.vertical,
    isHorizontalRtl: false,
    forwardControlDirection: AxisDirection.down,
    backwardControlDirection: AxisDirection.up,
    forwardFromNegativeDirection: false,
    backwardFromNegativeDirection: true,
  ),
  _ModeExpectation(
    inputMode: ReaderMode.continuousVertical,
    resolvedMode: ReaderMode.continuousVertical,
    axis: Axis.vertical,
    isHorizontalRtl: false,
    forwardControlDirection: AxisDirection.down,
    backwardControlDirection: AxisDirection.up,
    forwardFromNegativeDirection: false,
    backwardFromNegativeDirection: true,
  ),
  _ModeExpectation(
    inputMode: ReaderMode.singleHorizontalLTR,
    resolvedMode: ReaderMode.singleHorizontalLTR,
    axis: Axis.horizontal,
    isHorizontalRtl: false,
    forwardControlDirection: AxisDirection.right,
    backwardControlDirection: AxisDirection.left,
    forwardFromNegativeDirection: false,
    backwardFromNegativeDirection: true,
  ),
  _ModeExpectation(
    inputMode: ReaderMode.singleHorizontalRTL,
    resolvedMode: ReaderMode.singleHorizontalRTL,
    axis: Axis.horizontal,
    isHorizontalRtl: true,
    forwardControlDirection: AxisDirection.left,
    backwardControlDirection: AxisDirection.right,
    forwardFromNegativeDirection: true,
    backwardFromNegativeDirection: false,
  ),
  _ModeExpectation(
    inputMode: ReaderMode.continuousHorizontalLTR,
    resolvedMode: ReaderMode.continuousHorizontalLTR,
    axis: Axis.horizontal,
    isHorizontalRtl: false,
    forwardControlDirection: AxisDirection.right,
    backwardControlDirection: AxisDirection.left,
    forwardFromNegativeDirection: false,
    backwardFromNegativeDirection: true,
  ),
  _ModeExpectation(
    inputMode: ReaderMode.continuousHorizontalRTL,
    resolvedMode: ReaderMode.continuousHorizontalRTL,
    axis: Axis.horizontal,
    isHorizontalRtl: true,
    forwardControlDirection: AxisDirection.left,
    backwardControlDirection: AxisDirection.right,
    forwardFromNegativeDirection: true,
    backwardFromNegativeDirection: false,
  ),
  _ModeExpectation(
    inputMode: ReaderMode.singleVertical,
    resolvedMode: ReaderMode.singleVertical,
    axis: Axis.vertical,
    isHorizontalRtl: false,
    forwardControlDirection: AxisDirection.down,
    backwardControlDirection: AxisDirection.up,
    forwardFromNegativeDirection: false,
    backwardFromNegativeDirection: true,
  ),
  _ModeExpectation(
    inputMode: ReaderMode.webtoon,
    resolvedMode: ReaderMode.webtoon,
    axis: Axis.vertical,
    isHorizontalRtl: false,
    forwardControlDirection: AxisDirection.down,
    backwardControlDirection: AxisDirection.up,
    forwardFromNegativeDirection: false,
    backwardFromNegativeDirection: true,
  ),
];
