// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../constants/app_constants.dart';
import '../../../../../../utils/extensions/cache_manager_extensions.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/misc/app_utils.dart';
import '../../../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../../../widgets/server_image.dart';
import '../../../../../settings/presentation/reader/widgets/reader_scroll_animation_tile/reader_scroll_animation_tile.dart';
import '../../../../domain/chapter/chapter_model.dart';
import '../../../../domain/chapter_page/chapter_page_model.dart';
import '../../../../domain/manga/manga_model.dart';
import '../../navigation/reader_navigation.dart';
import '../reader_wrapper.dart';

class SinglePageReaderMode extends HookConsumerWidget {
  const SinglePageReaderMode({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapterPages,
    required this.initialOverlayVisible,
    required this.navigation,
    required this.beforeChapterChange,
    required this.onChapterChangeCommitted,
    this.onPageChanged,
    this.showReaderLayoutAnimation = false,
  });

  final MangaDto manga;
  final ChapterDto chapter;
  final ValueSetter<int>? onPageChanged;
  final ResolvedReaderNavigation navigation;
  final AsyncCallback beforeChapterChange;
  final VoidCallback onChapterChangeCommitted;
  final bool showReaderLayoutAnimation;
  final bool initialOverlayVisible;
  final ChapterPagesDto chapterPages;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheManager = useMemoized(() => DefaultCacheManager());
    final lastPageIndex =
        chapterPages.pages.isEmpty ? 0 : chapterPages.pages.length - 1;
    final initialPage = chapter.isRead.ifNull()
        ? 0
        : chapter.lastPageRead
            .getValueOnNullOrNegative()
            .clamp(0, lastPageIndex)
            .toInt();
    final scrollController = usePageController(
      initialPage: initialPage,
    );
    final currentIndex = useState(initialPage);
    final navigationState = useState(
      ReaderNavigationState(
        displayPageIndex: initialPage,
        atStart: chapterPages.pages.isEmpty || initialPage == 0,
        atEnd: chapterPages.pages.isEmpty || initialPage == lastPageIndex,
        isBusy: false,
      ),
    );

    useEffect(() {
      if (onPageChanged != null) onPageChanged!(currentIndex.value);
      int currentPage = currentIndex.value;
      // Only prefetch if we have pages data
      if (chapterPages.pages.isNotEmpty) {
        // Prev page
        if (currentPage > 0 && currentPage - 1 < chapterPages.pages.length) {
          cacheManager.getServerFile(
            ref,
            chapterPages.pages[currentPage - 1],
            appendApiToUrl: false,
          );
        }
        // Next page
        if (currentPage < (chapterPages.pages.length - 1)) {
          cacheManager.getServerFile(
            ref,
            chapterPages.pages[currentPage + 1],
            appendApiToUrl: false,
          );
        }
        // 2nd next page
        if (currentPage < (chapterPages.pages.length - 2)) {
          cacheManager.getServerFile(
            ref,
            chapterPages.pages[currentPage + 2],
            appendApiToUrl: false,
          );
        }
      }
      return null;
    }, [currentIndex.value, chapterPages.pages.length]);
    final isAnimationEnabled =
        ref.read(readerScrollAnimationProvider).ifNull(true);

    final stepPage = useCallback<ReaderPageStep>((direction) async {
      if (chapterPages.pages.isEmpty || !scrollController.hasClients) {
        return ReaderPageStepResult.unavailable;
      }

      final settledPage = scrollController.page?.round() ?? currentIndex.value;
      final delta = direction == ReadingDirection.forward ? 1 : -1;
      final targetPage = settledPage + delta;
      if (targetPage < 0 || targetPage > lastPageIndex) {
        return ReaderPageStepResult.atBoundary;
      }

      navigationState.value = navigationState.value.copyWith(isBusy: true);
      try {
        if (isAnimationEnabled) {
          await scrollController.animateToPage(
            targetPage,
            duration: kDuration,
            curve: kCurve,
          );
        } else {
          scrollController.jumpToPage(targetPage);
          await WidgetsBinding.instance.endOfFrame;
        }
      } finally {
        if (context.mounted) {
          navigationState.value = navigationState.value.copyWith(isBusy: false);
        }
      }
      return ReaderPageStepResult.moved;
    }, [
      chapterPages.pages.length,
      currentIndex.value,
      isAnimationEnabled,
      lastPageIndex,
      navigationState,
      scrollController,
    ]);

    final jumpToPage = useCallback<ReaderPageJump>((index) async {
      if (!scrollController.hasClients || chapterPages.pages.isEmpty) return;
      navigationState.value = navigationState.value.copyWith(isBusy: true);
      try {
        scrollController.jumpToPage(index.clamp(0, lastPageIndex));
        await WidgetsBinding.instance.endOfFrame;
      } finally {
        if (context.mounted) {
          navigationState.value = navigationState.value.copyWith(isBusy: false);
        }
      }
    }, [
      chapterPages.pages.length,
      lastPageIndex,
      navigationState,
      scrollController,
    ]);

    bool trackUserScrolling(ScrollNotification notification) {
      if (notification.depth != 0) return false;
      if (notification is ScrollStartNotification &&
          notification.dragDetails != null) {
        navigationState.value = navigationState.value.copyWith(isBusy: true);
      } else if (notification is ScrollEndNotification) {
        navigationState.value = navigationState.value.copyWith(isBusy: false);
      }
      return false;
    }

    return ReaderWrapper(
      navigation: navigation,
      chapter: chapter,
      manga: manga,
      chapterPages: chapterPages,
      navigationState: navigationState,
      initialOverlayVisible: initialOverlayVisible,
      onStepPage: stepPage,
      onJumpToPage: jumpToPage,
      beforeChapterChange: beforeChapterChange,
      onChapterChangeCommitted: onChapterChangeCommitted,
      showReaderLayoutAnimation: showReaderLayoutAnimation,
      childBuilder: (_) => NotificationListener<ScrollNotification>(
        onNotification: trackUserScrolling,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PageView.builder(
            scrollDirection: navigation.axis,
            reverse: navigation.pageViewReverse,
            controller: scrollController,
            allowImplicitScrolling: true,
            onPageChanged: (index) {
              currentIndex.value = index;
              navigationState.value = navigationState.value.copyWith(
                displayPageIndex: index,
                atStart: index == 0,
                atEnd: index == lastPageIndex,
              );
            },
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            itemBuilder: (BuildContext context, int index) {
              // Show loading indicator if no pages are available yet
              if (chapterPages.pages.isEmpty) {
                return const Center(
                  child: CenterSorayomiShimmerIndicator(),
                );
              }

              // Add bounds checking to prevent accessing non-existent pages
              if (index >= chapterPages.pages.length) {
                return const Center(
                  child: CenterSorayomiShimmerIndicator(),
                );
              }

              final image = ServerImage(
                key: ValueKey(
                  'single-page-${chapter.id}-$index-${chapterPages.pages[index]}',
                ),
                showReloadButton: true,
                fit: BoxFit.contain,
                size: Size.fromHeight(context.height),
                appendApiToUrl: false,
                imageUrl: chapterPages.pages[index],
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    CenterSorayomiShimmerIndicator(
                  value: downloadProgress.progress,
                ),
              );
              return AppUtils.wrapOn(
                !kIsWeb && (Platform.isAndroid || Platform.isIOS)
                    ? (child) => InteractiveViewer(maxScale: 5, child: child)
                    : null,
                image,
              );
            },
            itemCount:
                chapterPages.pages.isEmpty ? 1 : chapterPages.pages.length,
          ),
        ),
      ),
    );
  }
}
