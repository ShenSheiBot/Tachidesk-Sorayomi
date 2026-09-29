// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/widgets.dart';

class ReaderInteractiveViewer extends StatelessWidget {
  const ReaderInteractiveViewer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        maxScale: 5,
        // Wheel input belongs to scrolling/page navigation, not zoom. Touch
        // pinch and native pointer-scale events remain enabled.
        scaleFactor: double.infinity,
        child: child,
      );
}
