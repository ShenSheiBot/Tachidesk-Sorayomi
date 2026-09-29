// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../navigation/reader_navigation.dart';

/// Converts vertical wheel ticks to page commands, independently of RTL or
/// wheel distance. The resolver prevents nested listeners from stepping twice.
class ReaderPageScrollListener extends StatelessWidget {
  const ReaderPageScrollListener({
    super.key,
    required this.onCommand,
    required this.child,
  });

  final ValueChanged<ReaderCommand> onCommand;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {
            onCommand(StepReaderPage(
              event.scrollDelta.dy > 0
                  ? ReadingDirection.forward
                  : ReadingDirection.backward,
            ));
          });
        },
        child: child,
      );
}
