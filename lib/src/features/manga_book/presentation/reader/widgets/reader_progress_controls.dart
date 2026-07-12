// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

import '../navigation/reader_navigation.dart';
import 'page_number_slider.dart';

class ReaderProgressControls extends StatelessWidget {
  const ReaderProgressControls({
    super.key,
    required this.navigation,
    required this.currentPageIndex,
    required this.pageCount,
    required this.onPageChanged,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.previousChapterTooltip,
    required this.nextChapterTooltip,
  });

  static const previousChapterButtonKey = Key('previous-chapter-button');
  static const nextChapterButtonKey = Key('next-chapter-button');

  final ResolvedReaderNavigation navigation;
  final int currentPageIndex;
  final int pageCount;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final String previousChapterTooltip;
  final String nextChapterTooltip;

  @override
  Widget build(BuildContext context) => Row(
        textDirection: navigation.controlTextDirection,
        children: [
          Card(
            shape: const CircleBorder(),
            child: IconButton(
              key: previousChapterButtonKey,
              onPressed: onPreviousChapter,
              tooltip: previousChapterTooltip,
              icon: Transform.flip(
                flipX: navigation.isHorizontalRtl,
                child: const Icon(Icons.skip_previous_rounded),
              ),
            ),
          ),
          Expanded(
            child: PageNumberSlider(
              currentValue: currentPageIndex,
              maxValue: pageCount,
              onChanged: onPageChanged,
              inverted: navigation.sliderInverted,
            ),
          ),
          Card(
            shape: const CircleBorder(),
            child: IconButton(
              key: nextChapterButtonKey,
              onPressed: onNextChapter,
              tooltip: nextChapterTooltip,
              icon: Transform.flip(
                flipX: navigation.isHorizontalRtl,
                child: const Icon(Icons.skip_next_rounded),
              ),
            ),
          ),
        ],
      );
}
