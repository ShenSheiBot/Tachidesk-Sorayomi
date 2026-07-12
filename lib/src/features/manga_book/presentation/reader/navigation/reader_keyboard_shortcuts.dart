// Copyright (c) 2023 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reader_navigation.dart';

class StepReaderPageIntent extends Intent {
  const StepReaderPageIntent(this.direction);

  final ReadingDirection direction;
}

class ChangeReaderChapterIntent extends Intent {
  const ChangeReaderChapterIntent(this.direction);

  final ReadingDirection direction;
}

class ToggleReaderOverlayIntent extends Intent {
  const ToggleReaderOverlayIntent();
}

ShortcutManager readerShortcutManager(ResolvedReaderNavigation navigation) {
  final left = navigation.axis == Axis.horizontal
      ? StepReaderPageIntent(
          navigation.directionForControl(AxisDirection.left),
        )
      : const ChangeReaderChapterIntent(ReadingDirection.backward);
  final right = navigation.axis == Axis.horizontal
      ? StepReaderPageIntent(
          navigation.directionForControl(AxisDirection.right),
        )
      : const ChangeReaderChapterIntent(ReadingDirection.forward);
  final up = navigation.axis == Axis.vertical
      ? const StepReaderPageIntent(ReadingDirection.backward)
      : const ChangeReaderChapterIntent(ReadingDirection.forward);
  final down = navigation.axis == Axis.vertical
      ? const StepReaderPageIntent(ReadingDirection.forward)
      : const ChangeReaderChapterIntent(ReadingDirection.backward);

  return ShortcutManager(
    shortcuts: {
      const SingleActivator(LogicalKeyboardKey.space):
          const StepReaderPageIntent(ReadingDirection.forward),
      const SingleActivator(LogicalKeyboardKey.space, shift: true):
          const StepReaderPageIntent(ReadingDirection.backward),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): left,
      const SingleActivator(LogicalKeyboardKey.keyA): left,
      const SingleActivator(LogicalKeyboardKey.arrowRight): right,
      const SingleActivator(LogicalKeyboardKey.keyD): right,
      const SingleActivator(LogicalKeyboardKey.arrowUp): up,
      const SingleActivator(LogicalKeyboardKey.keyW): up,
      const SingleActivator(LogicalKeyboardKey.arrowDown): down,
      const SingleActivator(LogicalKeyboardKey.keyS): down,
      const SingleActivator(LogicalKeyboardKey.escape):
          const ToggleReaderOverlayIntent(),
    },
  );
}
