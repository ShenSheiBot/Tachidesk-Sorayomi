// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../navigation/reader_navigation.dart';

class ChapterSeparator extends StatelessWidget {
  const ChapterSeparator({
    super.key,
    required this.chapter,
    required this.previousChapter,
    required this.nextChapter,
    required this.showChapterButtons,
    required this.onChangeChapter,
    required this.isPreviousChapterSeparator,
  });

  final ChapterDto chapter;
  final ChapterDto? previousChapter;
  final ChapterDto? nextChapter;
  final bool showChapterButtons;
  final ValueChanged<ReadingDirection> onChangeChapter;
  final bool isPreviousChapterSeparator;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Gap(16),
              if (showChapterButtons &&
                  previousChapter != null &&
                  isPreviousChapterSeparator)
                Padding(
                  padding: KEdgeInsets.v16.size,
                  child: FilledButton(
                    onPressed: () => onChangeChapter(ReadingDirection.backward),
                    child: Text(
                      context.l10n.previousChapter(previousChapter!.name),
                    ),
                  ),
                ),
              Text(
                isPreviousChapterSeparator
                    ? context.l10n.start
                    : context.l10n.finished,
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                chapter.name,
                style: context.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              if (showChapterButtons &&
                  nextChapter != null &&
                  !isPreviousChapterSeparator)
                Padding(
                  padding: KEdgeInsets.v16.size,
                  child: FilledButton(
                    onPressed: () => onChangeChapter(ReadingDirection.forward),
                    child: Text(context.l10n.nextChapter(nextChapter!.name)),
                  ),
                ),
              const Gap(16),
            ],
          ),
        ),
      );
}
