// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../../constants/enum.dart';

enum ReadingDirection { backward, forward }

enum ReaderPageStepResult { moved, atBoundary, unavailable }

enum ReaderBoundaryBehavior { stop, changeChapter }

int resolveInitialReaderPage({
  required int pageCount,
  required int lastPageRead,
  required bool isChapterRead,
  required bool openAtEnd,
}) {
  if (pageCount <= 0) return 0;
  if (openAtEnd) return pageCount - 1;
  if (isChapterRead) return 0;
  return lastPageRead.clamp(0, pageCount - 1).toInt();
}

sealed class ReaderCommand {
  const ReaderCommand();
}

final class StepReaderPage extends ReaderCommand {
  const StepReaderPage(
    this.direction, {
    this.atBoundary = ReaderBoundaryBehavior.changeChapter,
  });

  final ReadingDirection direction;
  final ReaderBoundaryBehavior atBoundary;
}

final class ChangeReaderChapter extends ReaderCommand {
  const ChangeReaderChapter(this.direction);

  final ReadingDirection direction;
}

final class JumpToReaderPage extends ReaderCommand {
  const JumpToReaderPage(this.index);

  final int index;
}

typedef ReaderPageStep = Future<ReaderPageStepResult> Function(
  ReadingDirection direction,
);
typedef ReaderPageJump = Future<void> Function(int index);
typedef ReaderChapterChange = FutureOr<bool> Function(
  ReadingDirection direction,
);

final class ReaderNavigationState {
  const ReaderNavigationState({
    required this.displayPageIndex,
    required this.atStart,
    required this.atEnd,
    required this.isBusy,
  });

  final int displayPageIndex;
  final bool atStart;
  final bool atEnd;
  final bool isBusy;

  ReaderNavigationState copyWith({
    int? displayPageIndex,
    bool? atStart,
    bool? atEnd,
    bool? isBusy,
  }) =>
      ReaderNavigationState(
        displayPageIndex: displayPageIndex ?? this.displayPageIndex,
        atStart: atStart ?? this.atStart,
        atEnd: atEnd ?? this.atEnd,
        isBusy: isBusy ?? this.isBusy,
      );
}

final class ReaderNavigationBindings {
  const ReaderNavigationBindings({
    required this.state,
    required this.stepPage,
    required this.jumpToPage,
    required this.changeChapter,
  });

  final ValueListenable<ReaderNavigationState> state;
  final ReaderPageStep stepPage;
  final ReaderPageJump jumpToPage;
  final ReaderChapterChange changeChapter;
}

final class ReaderNavigationCoordinator {
  static const _maxQueuedPageCommands = 8;

  bool _isExecuting = false;
  bool _chapterTransitionStarted = false;
  bool _isDisposed = false;
  final ListQueue<_QueuedReaderCommand> _pending = ListQueue();
  final Set<VoidCallback> _cancelIdleWaits = {};

  bool get isExecuting => _isExecuting;
  bool get chapterTransitionStarted => _chapterTransitionStarted;

  Future<void> dispatch(
    ReaderCommand command,
    ReaderNavigationBindings bindings,
  ) async {
    if (_isDisposed || _chapterTransitionStarted) return;
    _enqueue(_QueuedReaderCommand(command, bindings));

    if (_isExecuting) return;

    _isExecuting = true;

    try {
      while (
          !_isDisposed && !_chapterTransitionStarted && _pending.isNotEmpty) {
        final queued = _pending.removeFirst();
        await _execute(queued.command, queued.bindings);
      }
    } finally {
      _isExecuting = false;
      if (_chapterTransitionStarted) _pending.clear();
    }
  }

  void _enqueue(_QueuedReaderCommand queued) {
    if (queued.command is ChangeReaderChapter) {
      _pending
        ..clear()
        ..add(queued);
      return;
    }
    if (_pending.any((item) => item.command is ChangeReaderChapter)) return;

    if (queued.command is JumpToReaderPage) {
      _pending
        ..clear()
        ..add(queued);
      return;
    }

    while (_pending.length >= _maxQueuedPageCommands) {
      _pending.removeFirst();
    }
    _pending.add(queued);
  }

  Future<void> _execute(
    ReaderCommand command,
    ReaderNavigationBindings bindings,
  ) async {
    switch (command) {
      case StepReaderPage(:final direction, :final atBoundary):
        if (!await _waitUntilIdle(bindings.state)) return;
        if (_isDisposed) return;
        if (_pending.any((item) => item.command is ChangeReaderChapter)) return;

        final state = bindings.state.value;
        final isAtRequestedBoundary =
            direction == ReadingDirection.forward ? state.atEnd : state.atStart;
        if (isAtRequestedBoundary) {
          if (atBoundary == ReaderBoundaryBehavior.changeChapter) {
            await _startChapterTransition(direction, bindings);
          }
          return;
        }

        final result = await bindings.stepPage(direction);
        if (_isDisposed) return;
        if (result == ReaderPageStepResult.atBoundary &&
            atBoundary == ReaderBoundaryBehavior.changeChapter) {
          final latestState = bindings.state.value;
          final boundaryConfirmed = direction == ReadingDirection.forward
              ? latestState.atEnd
              : latestState.atStart;
          if (boundaryConfirmed) {
            await _startChapterTransition(direction, bindings);
          }
        }
      case ChangeReaderChapter(:final direction):
        await _startChapterTransition(direction, bindings);
      case JumpToReaderPage(:final index):
        await bindings.jumpToPage(index);
    }
  }

  Future<void> _startChapterTransition(
    ReadingDirection direction,
    ReaderNavigationBindings bindings,
  ) async {
    final transitionStarted = await bindings.changeChapter(direction);
    if (!_isDisposed && transitionStarted) {
      _chapterTransitionStarted = true;
    }
  }

  Future<bool> _waitUntilIdle(
    ValueListenable<ReaderNavigationState> state,
  ) async {
    if (!state.value.isBusy) return true;

    final completer = Completer<bool>();
    late VoidCallback listener;
    late VoidCallback cancel;

    listener = () {
      if (!state.value.isBusy && !completer.isCompleted) {
        completer.complete(true);
      }
    };
    cancel = () {
      if (!completer.isCompleted) completer.complete(false);
    };

    _cancelIdleWaits.add(cancel);
    state.addListener(listener);
    listener();
    try {
      return await completer.future;
    } finally {
      state.removeListener(listener);
      _cancelIdleWaits.remove(cancel);
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final cancel in _cancelIdleWaits.toList()) {
      cancel();
    }
    _cancelIdleWaits.clear();
    _pending.clear();
  }
}

final class ResolvedReaderNavigation {
  const ResolvedReaderNavigation._(this.mode);

  factory ResolvedReaderNavigation.fromMode(ReaderMode mode) =>
      ResolvedReaderNavigation._(
        mode == ReaderMode.defaultReader ? ReaderMode.webtoon : mode,
      );

  final ReaderMode mode;

  static ReaderMode resolveMode({
    required ReaderMode? mangaReaderMode,
    required ReaderMode? defaultReaderMode,
  }) {
    if (mangaReaderMode == null ||
        mangaReaderMode == ReaderMode.defaultReader) {
      final resolvedDefault = defaultReaderMode ?? ReaderMode.webtoon;
      return resolvedDefault == ReaderMode.defaultReader
          ? ReaderMode.webtoon
          : resolvedDefault;
    }
    return mangaReaderMode;
  }

  Axis get axis => switch (mode) {
        ReaderMode.singleHorizontalLTR ||
        ReaderMode.singleHorizontalRTL ||
        ReaderMode.continuousHorizontalLTR ||
        ReaderMode.continuousHorizontalRTL =>
          Axis.horizontal,
        ReaderMode.singleVertical ||
        ReaderMode.continuousVertical ||
        ReaderMode.webtoon ||
        ReaderMode.defaultReader =>
          Axis.vertical,
      };

  bool get isHorizontalRtl => switch (mode) {
        ReaderMode.singleHorizontalRTL ||
        ReaderMode.continuousHorizontalRTL =>
          true,
        _ => false,
      };

  bool get pageViewReverse => isHorizontalRtl;
  bool get sliderInverted => isHorizontalRtl;

  TextDirection get controlTextDirection =>
      isHorizontalRtl ? TextDirection.rtl : TextDirection.ltr;

  AxisDirection get forwardControlDirection => switch (axis) {
        Axis.horizontal =>
          isHorizontalRtl ? AxisDirection.left : AxisDirection.right,
        Axis.vertical => AxisDirection.down,
      };

  AxisDirection get backwardControlDirection =>
      _opposite(forwardControlDirection);

  ReadingDirection directionForControl(AxisDirection direction) {
    if (direction == forwardControlDirection) return ReadingDirection.forward;
    if (direction == backwardControlDirection) {
      return ReadingDirection.backward;
    }
    throw ArgumentError.value(
      direction,
      'direction',
      'Direction must be on the reader axis',
    );
  }

  ReaderChapterTransition chapterTransition(ReadingDirection direction) {
    final entryFrom = direction == ReadingDirection.forward
        ? forwardControlDirection
        : backwardControlDirection;
    return ReaderChapterTransition(
      entryFrom: entryFrom,
      openAtEnd: direction == ReadingDirection.backward,
    );
  }

  static AxisDirection _opposite(AxisDirection direction) =>
      switch (direction) {
        AxisDirection.up => AxisDirection.down,
        AxisDirection.right => AxisDirection.left,
        AxisDirection.down => AxisDirection.up,
        AxisDirection.left => AxisDirection.right,
      };
}

final class ReaderChapterTransition {
  const ReaderChapterTransition({
    required this.entryFrom,
    required this.openAtEnd,
  });

  final AxisDirection entryFrom;
  final bool openAtEnd;

  bool get isVertical =>
      entryFrom == AxisDirection.up || entryFrom == AxisDirection.down;
  bool get fromNegativeDirection =>
      entryFrom == AxisDirection.up || entryFrom == AxisDirection.left;
}

final class _QueuedReaderCommand {
  const _QueuedReaderCommand(this.command, this.bindings);

  final ReaderCommand command;
  final ReaderNavigationBindings bindings;
}
