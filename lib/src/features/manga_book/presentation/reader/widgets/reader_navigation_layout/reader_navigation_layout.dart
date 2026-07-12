// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../../constants/app_constants.dart';
import '../../../../../../constants/enum.dart';
import '../../navigation/reader_navigation.dart';
import 'layouts/edge_layout.dart';
import 'layouts/kindlish_layout.dart';
import 'layouts/l_shaped_layout.dart';
import 'layouts/right_and_left_layout.dart';

class ReaderNavigationLayoutWidget extends HookWidget {
  const ReaderNavigationLayoutWidget({
    super.key,
    this.navigationLayout,
    required this.navigation,
    required this.invertTap,
    required this.onPrevious,
    required this.onNext,
    this.showReaderLayoutAnimation = false,
  });
  final ReaderNavigationLayout? navigationLayout;
  final ResolvedReaderNavigation navigation;
  final bool invertTap;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool showReaderLayoutAnimation;
  @override
  Widget build(BuildContext context) {
    final animationController = useAnimationController(duration: kLongDuration);
    useAnimation(animationController);
    final nextColorTween = ColorTween(
      begin: showReaderLayoutAnimation ? Colors.green : Colors.transparent,
    ).animate(animationController).value;

    final prevColorTween = ColorTween(
      begin: showReaderLayoutAnimation ? Colors.blue : Colors.transparent,
    ).animate(animationController).value;
    useEffect(() {
      animationController.forward();
      return;
    }, []);

    final layout = navigationLayout;
    final nextOnLeft = navigation.isHorizontalRtl != invertTap;
    final VoidCallback? onLeftTap;
    final VoidCallback? onRightTap;
    final Color? leftColor;
    final Color? rightColor;
    if (nextOnLeft) {
      onLeftTap = onNext;
      onRightTap = onPrevious;
      leftColor = nextColorTween;
      rightColor = prevColorTween;
    } else {
      onLeftTap = onPrevious;
      onRightTap = onNext;
      leftColor = prevColorTween;
      rightColor = nextColorTween;
    }
    return switch (layout) {
      ReaderNavigationLayout.edge => EdgeLayout(
          onLeftTap: onLeftTap,
          onRightTap: onRightTap,
          leftColor: leftColor,
          rightColor: rightColor,
        ),
      ReaderNavigationLayout.kindlish => KindlishLayout(
          onLeftTap: onLeftTap,
          onRightTap: onRightTap,
          leftColor: leftColor,
          rightColor: rightColor,
        ),
      ReaderNavigationLayout.lShaped => LShapedLayout(
          onLeftTap: onLeftTap,
          onRightTap: onRightTap,
          leftColor: leftColor,
          rightColor: rightColor,
        ),
      ReaderNavigationLayout.rightAndLeft => RightAndLeftLayout(
          onLeftTap: onLeftTap,
          onRightTap: onRightTap,
          leftColor: leftColor,
          rightColor: rightColor,
        ),
      ReaderNavigationLayout.defaultNavigation ||
      ReaderNavigationLayout.disabled ||
      null =>
        const SizedBox.shrink(),
    };
  }
}
