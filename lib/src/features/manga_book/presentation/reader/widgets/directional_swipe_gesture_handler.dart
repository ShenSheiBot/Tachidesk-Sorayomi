// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../navigation/reader_navigation.dart';

class DirectionalSwipeGestureHandler extends HookWidget {
  const DirectionalSwipeGestureHandler({
    super.key,
    required this.child,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onLongPressMoveUpdate,
    required this.scrollDirection,
    required this.readerSwipeChapterToggle,
    required this.lastPageSwipeEnabled,
    required this.onChangeChapter,
  });

  static const _edgeSwipeThreshold = 12.0;
  static const _chapterSwipeVelocityThreshold = 8.0;

  final Widget child;
  final VoidCallback onTap;
  final void Function(LongPressStartDetails) onLongPressStart;
  final void Function(LongPressEndDetails) onLongPressEnd;
  final void Function(LongPressMoveUpdateDetails) onLongPressMoveUpdate;
  final Axis scrollDirection;
  final bool readerSwipeChapterToggle;
  final bool lastPageSwipeEnabled;
  final ValueChanged<ReadingDirection> onChangeChapter;

  @override
  Widget build(BuildContext context) {
    final accumulatedOverscroll = useRef(0.0);
    final edgeSwipeTriggered = useRef(false);

    void resetEdgeSwipe() {
      accumulatedOverscroll.value = 0;
      edgeSwipeTriggered.value = false;
    }

    bool onScrollNotification(ScrollNotification notification) {
      if (readerSwipeChapterToggle || !lastPageSwipeEnabled) return false;
      if (notification.depth != 0 ||
          notification.metrics.axis != scrollDirection) {
        return false;
      }

      if (notification is ScrollStartNotification) {
        resetEdgeSwipe();
      } else if (notification is OverscrollNotification &&
          !edgeSwipeTriggered.value) {
        accumulatedOverscroll.value += notification.overscroll.abs();
        if (accumulatedOverscroll.value >= _edgeSwipeThreshold) {
          edgeSwipeTriggered.value = true;
          onChangeChapter(
            notification.overscroll > 0
                ? ReadingDirection.forward
                : ReadingDirection.backward,
          );
        }
      } else if (notification is ScrollEndNotification) {
        resetEdgeSwipe();
      }
      return false;
    }

    void onPerpendicularDragEnd(DragEndDetails details) {
      final velocity = details.primaryVelocity;
      if (velocity == null ||
          velocity.abs() <= _chapterSwipeVelocityThreshold) {
        return;
      }
      onChangeChapter(
        velocity < 0 ? ReadingDirection.forward : ReadingDirection.backward,
      );
    }

    final gestureHandler = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onHorizontalDragEnd:
          readerSwipeChapterToggle && scrollDirection == Axis.vertical
              ? onPerpendicularDragEnd
              : null,
      onVerticalDragEnd:
          readerSwipeChapterToggle && scrollDirection == Axis.horizontal
              ? onPerpendicularDragEnd
              : null,
      child: child,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: onScrollNotification,
      child: gestureHandler,
    );
  }
}
