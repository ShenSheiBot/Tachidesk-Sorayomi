// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/misc/app_utils.dart';
import '../../../../../../widgets/server_image.dart';
import '../../../../../settings/presentation/reader/widgets/reader_pinch_to_zoom/reader_pinch_to_zoom.dart';
import '../../../../../settings/presentation/reader/widgets/reader_scroll_animation_tile/reader_scroll_animation_tile.dart';
import '../../../../domain/chapter/chapter_model.dart';
import '../../../../domain/chapter_page/chapter_page_model.dart';
import '../../../../domain/manga/manga_model.dart';
import '../../navigation/reader_navigation.dart';
import '../chapter_separator.dart';
import '../reader_wrapper.dart';

class ContinuousReaderMode extends HookConsumerWidget {
  const ContinuousReaderMode({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapterPages,
    required this.initialOverlayVisible,
    required this.navigation,
    required this.initialPage,
    required this.beforeChapterChange,
    required this.onChapterChangeCommitted,
    this.showSeparator = false,
    this.onPageChanged,
    this.showReaderLayoutAnimation = false,
  });

  static const _positionEpsilon = 0.001;

  final MangaDto manga;
  final ChapterDto chapter;
  final bool showSeparator;
  final ValueSetter<int>? onPageChanged;
  final ResolvedReaderNavigation navigation;
  final int initialPage;
  final AsyncCallback beforeChapterChange;
  final VoidCallback onChapterChangeCommitted;
  final bool showReaderLayoutAnimation;
  final bool initialOverlayVisible;
  final ChapterPagesDto chapterPages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useMemoized(ItemScrollController.new);
    final positionsListener = useMemoized(ItemPositionsListener.create);
    final actualPageCount = chapterPages.pages.length;
    final lastPageIndex = actualPageCount == 0 ? 0 : actualPageCount - 1;
    final navigationState = useState(
      ReaderNavigationState(
        displayPageIndex: initialPage,
        atStart: actualPageCount == 0,
        atEnd: actualPageCount == 0,
        isBusy: false,
      ),
    );

    useEffect(() {
      void updateViewport() {
        if (!context.mounted) return;
        navigationState.value = projectNavigationState(
          positions: positionsListener.itemPositions.value,
          pageCount: actualPageCount,
          previous: navigationState.value,
        );
      }

      positionsListener.itemPositions.addListener(updateViewport);
      WidgetsBinding.instance.addPostFrameCallback((_) => updateViewport());
      return () =>
          positionsListener.itemPositions.removeListener(updateViewport);
    }, [actualPageCount, positionsListener]);

    useEffect(() {
      onPageChanged?.call(navigationState.value.displayPageIndex);
      return null;
    }, [navigationState.value.displayPageIndex]);

    final isAnimationEnabled =
        ref.read(readerScrollAnimationProvider).ifNull(true);
    final isPinchToZoomEnabled = ref.read(pinchToZoomProvider).ifNull(true);

    Future<void> scrollToItem(int itemIndex) async {
      navigationState.value = navigationState.value.copyWith(isBusy: true);
      try {
        if (isAnimationEnabled) {
          await scrollController.scrollTo(
            index: itemIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } else {
          scrollController.jumpTo(index: itemIndex);
          await WidgetsBinding.instance.endOfFrame;
        }
      } finally {
        if (context.mounted) {
          navigationState.value = projectNavigationState(
            positions: positionsListener.itemPositions.value,
            pageCount: actualPageCount,
            previous: navigationState.value.copyWith(isBusy: false),
          );
        }
      }
    }

    final stepPage = useCallback<ReaderPageStep>((direction) async {
      if (actualPageCount == 0 ||
          !scrollController.isAttached ||
          positionsListener.itemPositions.value.isEmpty) {
        return ReaderPageStepResult.unavailable;
      }

      final state = navigationState.value;
      if ((direction == ReadingDirection.forward && state.atEnd) ||
          (direction == ReadingDirection.backward && state.atStart)) {
        return ReaderPageStepResult.atBoundary;
      }

      final targetItem = targetItemForStep(
        direction: direction,
        state: state,
        pageCount: actualPageCount,
      );
      await scrollToItem(targetItem);
      return ReaderPageStepResult.moved;
    }, [
      actualPageCount,
      isAnimationEnabled,
      lastPageIndex,
      navigationState,
      positionsListener,
      scrollController,
    ]);

    final jumpToPage = useCallback<ReaderPageJump>((index) async {
      if (actualPageCount == 0 || !scrollController.isAttached) return;
      final pageIndex = index.clamp(0, lastPageIndex);
      await scrollToItem(pageIndex + 1);
    }, [
      actualPageCount,
      isAnimationEnabled,
      lastPageIndex,
      navigationState,
      positionsListener,
      scrollController,
    ]);

    bool trackUserScrolling(ScrollNotification notification) {
      if (notification.depth != 0) return false;
      if (notification is ScrollStartNotification &&
          notification.dragDetails != null) {
        navigationState.value = navigationState.value.copyWith(isBusy: true);
      } else if (notification is ScrollEndNotification) {
        navigationState.value = projectNavigationState(
          positions: positionsListener.itemPositions.value,
          pageCount: actualPageCount,
          previous: navigationState.value.copyWith(isBusy: false),
        );
      }
      return false;
    }

    Widget buildList(ReaderContentNavigation contentNavigation) =>
        NotificationListener<ScrollNotification>(
          onNotification: trackUserScrolling,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ScrollablePositionedList.separated(
              itemScrollController: scrollController,
              itemPositionsListener: positionsListener,
              initialScrollIndex: actualPageCount == 0 ? 0 : initialPage + 1,
              scrollDirection: navigation.axis,
              reverse: navigation.pageViewReverse,
              itemCount: actualPageCount == 0 ? 1 : actualPageCount + 2,
              minCacheExtent: navigation.axis == Axis.vertical
                  ? context.height * 2
                  : context.width * 2,
              separatorBuilder: (_, __) =>
                  showSeparator ? const Gap(16) : const SizedBox.shrink(),
              itemBuilder: (context, itemIndex) {
                if (actualPageCount == 0) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (itemIndex == 0 || itemIndex == actualPageCount + 1) {
                  return SizedBox(
                    height: navigation.axis == Axis.vertical
                        ? context.height * .5
                        : null,
                    width: navigation.axis == Axis.horizontal
                        ? context.width * .5
                        : null,
                    child: ChapterSeparator(
                      chapter: chapter,
                      previousChapter: contentNavigation.previousChapter,
                      nextChapter: contentNavigation.nextChapter,
                      showChapterButtons: contentNavigation.showChapterButtons,
                      onChangeChapter: (direction) =>
                          contentNavigation.onCommand(
                        ChangeReaderChapter(direction),
                      ),
                      isPreviousChapterSeparator: itemIndex == 0,
                    ),
                  );
                }

                final pageIndex = itemIndex - 1;
                return ServerImage(
                  key: ValueKey(
                    'continuous-page-${chapter.id}-$pageIndex-'
                    '${chapterPages.pages[pageIndex]}',
                  ),
                  showReloadButton: true,
                  fit: navigation.axis == Axis.vertical
                      ? BoxFit.fitWidth
                      : BoxFit.fitHeight,
                  appendApiToUrl: false,
                  imageUrl: chapterPages.pages[pageIndex],
                  progressIndicatorBuilder: (_, __, downloadProgress) => Center(
                    child: CircularProgressIndicator(
                      value: downloadProgress.progress,
                    ),
                  ),
                  wrapper: (child) => SizedBox(
                    height: navigation.axis == Axis.vertical
                        ? context.height * .7
                        : null,
                    width: navigation.axis == Axis.horizontal
                        ? context.width * .7
                        : null,
                    child: child,
                  ),
                );
              },
            ),
          ),
        );

    return ReaderWrapper(
      navigation: navigation,
      chapterPages: chapterPages,
      chapter: chapter,
      manga: manga,
      showReaderLayoutAnimation: showReaderLayoutAnimation,
      navigationState: navigationState,
      initialOverlayVisible: initialOverlayVisible,
      onStepPage: stepPage,
      onJumpToPage: jumpToPage,
      beforeChapterChange: beforeChapterChange,
      onChapterChangeCommitted: onChapterChangeCommitted,
      childBuilder: (contentNavigation) => AppUtils.wrapOn(
        !kIsWeb &&
                (Platform.isAndroid || Platform.isIOS) &&
                isPinchToZoomEnabled
            ? (child) => InteractiveViewer(maxScale: 5, child: child)
            : null,
        buildList(contentNavigation),
      ),
    );
  }

  @visibleForTesting
  static int targetItemForStep({
    required ReadingDirection direction,
    required ReaderNavigationState state,
    required int pageCount,
  }) {
    final lastPageIndex = pageCount - 1;
    return switch (direction) {
      ReadingDirection.forward => state.atStart
          ? 1
          : state.displayPageIndex < lastPageIndex
              ? state.displayPageIndex + 2
              : pageCount + 1,
      ReadingDirection.backward => state.atEnd
          ? pageCount
          : state.displayPageIndex > 0
              ? state.displayPageIndex
              : 0,
    };
  }

  @visibleForTesting
  static ReaderNavigationState projectNavigationState({
    required Iterable<ItemPosition> positions,
    required int pageCount,
    required ReaderNavigationState previous,
  }) {
    if (pageCount <= 0) {
      return previous.copyWith(
        displayPageIndex: 0,
        atStart: true,
        atEnd: true,
      );
    }

    ItemPosition? startSentinel;
    ItemPosition? endSentinel;
    ItemPosition? mostVisiblePage;
    var mostVisibleArea = -1.0;

    for (final position in positions) {
      if (position.index == 0) {
        startSentinel = position;
        continue;
      }
      if (position.index == pageCount + 1) {
        endSentinel = position;
        continue;
      }
      if (position.index < 1 || position.index > pageCount) continue;

      final visibleArea = _visibleArea(position);
      final shouldReplace = visibleArea > mostVisibleArea ||
          (visibleArea == mostVisibleArea &&
              position.index - 1 == previous.displayPageIndex);
      if (shouldReplace) {
        mostVisibleArea = visibleArea;
        mostVisiblePage = position;
      }
    }

    return previous.copyWith(
      displayPageIndex:
          mostVisiblePage?.index == null ? null : mostVisiblePage!.index - 1,
      atStart: startSentinel != null &&
          startSentinel.itemLeadingEdge >= -_positionEpsilon,
      atEnd: endSentinel != null &&
          endSentinel.itemTrailingEdge <= 1 + _positionEpsilon,
    );
  }

  static double _visibleArea(ItemPosition position) {
    final leading = position.itemLeadingEdge.clamp(0.0, 1.0);
    final trailing = position.itemTrailingEdge.clamp(0.0, 1.0);
    return (trailing - leading).clamp(0.0, 1.0);
  }
}
