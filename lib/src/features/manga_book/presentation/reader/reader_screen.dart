// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/enum.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../history/presentation/history_controller.dart';
import '../../../library/presentation/category/controller/edit_category_controller.dart';
import '../../../library/presentation/library/controller/library_controller.dart';
import '../../../settings/presentation/reader/widgets/reader_ignore_safe_area_tile/reader_ignore_safe_area_tile.dart';
import '../../../settings/presentation/reader/widgets/reader_initial_overlay_tile/reader_initial_overlay_tile.dart';
import '../../../settings/presentation/reader/widgets/reader_mode_tile/reader_mode_tile.dart';
import '../../data/manga_book/manga_book_repository.dart';
import '../../domain/chapter_batch/chapter_batch_model.dart';
import '../../domain/manga/manga_model.dart';
import '../manga_details/controller/manga_details_controller.dart';
import 'controller/reader_controller.dart';
import 'navigation/reader_navigation.dart';
import 'navigation/reader_progress_debouncer.dart';
import 'widgets/reader_mode/continuous_reader_mode.dart';
import 'widgets/reader_mode/single_page_reader_mode.dart';

class ReaderScreen extends HookConsumerWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    this.useInitialReaderOverlay = true,
    this.showReaderLayoutAnimation = false,
  });
  final int mangaId;
  final int chapterId;
  final bool useInitialReaderOverlay;
  final bool showReaderLayoutAnimation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaProvider = mangaWithIdProvider(mangaId: mangaId);
    final chapterProviderWithIndex = chapterProvider(chapterId: chapterId);
    final chapterPages = ref.watch(chapterPagesProvider(chapterId: chapterId));
    final manga = ref.watch(mangaProvider);
    final chapter = ref.watch(chapterProviderWithIndex);
    final defaultReaderMode = ref.watch(readerModeKeyProvider);
    final ignoreSafeArea = ref.watch(readerIgnoreSafeAreaProvider).ifNull();
    final initialOverlayVisible = useInitialReaderOverlay
        ? ref.watch(readerInitialOverlayProvider).ifNull()
        : false;

    final isChangingChapter = useRef(false);
    final isExiting = useRef(false);
    final completionRequested = useRef(false);
    final allowPop = useState(false);
    final lastSavedPage = useRef(
      chapter.valueOrNull?.lastPageRead.getValueOnNullOrNegative() ?? 0,
    );

    final updateLastRead = useCallback((int currentPage) async {
      final chapterValue = chapter.valueOrNull;
      final chapterPagesValue = chapterPages.valueOrNull;
      if (chapterValue == null || chapterPagesValue == null) return false;
      final knownLastPage =
          chapterValue.lastPageRead.getValueOnNullOrNegative();
      if (knownLastPage > lastSavedPage.value) {
        lastSavedPage.value = knownLastPage;
      }

      // Use the actual loaded pages count, not the chapter's pageCount metadata
      final actualPageCount = chapterPagesValue.pages.length;

      // Only mark as completed if we've reached the actual last page
      final isReadingCompleted =
          (currentPage >= (actualPageCount - 1)) && actualPageCount > 0;

      if (!isReadingCompleted && currentPage <= lastSavedPage.value) {
        return true;
      }

      final response = await AsyncValue.guard(
        () => ref.read(mangaBookRepositoryProvider).putChapter(
              chapterId: chapterValue.id,
              patch: ChapterChange(
                lastPageRead: isReadingCompleted ? 0 : currentPage,
                isRead: isReadingCompleted,
              ),
            ),
      );
      if (response.hasError) {
        return false;
      }
      if (!context.mounted) return true;
      lastSavedPage.value = isReadingCompleted ? 0 : currentPage;

      // Invalidate history to refresh the reading progress
      ref.invalidate(readingHistoryProvider);
      if (isReadingCompleted) {
        ref.invalidate(chapterProvider(chapterId: chapterValue.id));
        ref.invalidate(mangaChapterListProvider(mangaId: mangaId));
        ref.invalidate(categoryMangaListProvider(0));
        final categories = ref.read(categoryControllerProvider).valueOrNull;
        for (final category in categories ?? []) {
          ref.invalidate(categoryMangaListProvider(category.id));
        }
      }
      return true;
    }, [chapter.valueOrNull, chapterPages.valueOrNull]);

    final progressDebouncer = useMemoized(
      () => ReaderProgressDebouncer(onSave: updateLastRead),
    )..onSave = updateLastRead;

    final onPageChanged = useCallback<AsyncValueSetter<int>>(
      (int index) async {
        final chapterValue = chapter.valueOrNull;
        final chapterPagesValue = chapterPages.valueOrNull;
        if (chapterValue == null || chapterPagesValue == null) return;
        final knownLastPage =
            chapterValue.lastPageRead.getValueOnNullOrNegative();
        if (knownLastPage > lastSavedPage.value) {
          lastSavedPage.value = knownLastPage;
        }

        // Use actual loaded pages count instead of chapter metadata
        final actualPageCount = chapterPagesValue.pages.length;
        final isAtLastPage =
            index >= (actualPageCount - 1) && actualPageCount > 0;

        // Skip if chapter is already read or if we're going backwards.
        // Still allow the last page to mark short/single-page chapters as read.
        if (completionRequested.value ||
            (chapterValue.isRead).ifNull() ||
            (!isAtLastPage && index <= lastSavedPage.value)) {
          return;
        }

        if (isAtLastPage) {
          completionRequested.value = true;
          final saved = await progressDebouncer.saveNow(index);
          if (!saved && context.mounted) {
            completionRequested.value = false;
          }
        } else {
          progressDebouncer.schedule(index);
        }
        return;
      },
      [chapter, chapterPages, progressDebouncer],
    );

    final flushReadingProgress = useCallback<AsyncCallback>(
      progressDebouncer.flushAndClose,
      [progressDebouncer],
    );
    final markChapterChangeCommitted = useCallback(
      () => isChangingChapter.value = true,
      [],
    );

    useEffect(() {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return () {
        if (!isChangingChapter.value) {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
        }
      };
    }, []);

    useEffect(() {
      return progressDebouncer.dispose;
    }, [progressDebouncer]);

    return PopScope(
      canPop: allowPop.value,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || isExiting.value) return;
        isExiting.value = true;
        await flushReadingProgress();
        if (!context.mounted) return;

        ref.invalidate(chapterProviderWithIndex);
        ref.invalidate(mangaChapterListProvider(mangaId: mangaId));
        allowPop.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: !ignoreSafeArea,
            bottom: !ignoreSafeArea,
            left: !ignoreSafeArea,
            right: !ignoreSafeArea,
            child: manga.showUiWhenData(
              context,
              (data) {
                if (data == null) return const SizedBox.shrink();
                return chapter.showUiWhenData(
                  context,
                  (chapterData) {
                    if (chapterData == null) return const SizedBox.shrink();
                    return chapterPages.showUiWhenData(
                      context,
                      (chapterPagesData) {
                        if (chapterPagesData == null) {
                          return const SizedBox.shrink();
                        }
                        final resolvedReaderMode =
                            ResolvedReaderNavigation.resolveMode(
                          mangaReaderMode: data.metaData.readerMode,
                          defaultReaderMode: defaultReaderMode,
                        );
                        final navigation = ResolvedReaderNavigation.fromMode(
                          resolvedReaderMode,
                        );
                        final reader = switch (resolvedReaderMode) {
                          ReaderMode.singleVertical => SinglePageReaderMode(
                              chapter: chapterData,
                              manga: data,
                              onPageChanged: onPageChanged,
                              initialOverlayVisible: initialOverlayVisible,
                              navigation: navigation,
                              beforeChapterChange: flushReadingProgress,
                              onChapterChangeCommitted:
                                  markChapterChangeCommitted,
                              showReaderLayoutAnimation:
                                  showReaderLayoutAnimation,
                              chapterPages: chapterPagesData,
                            ),
                          ReaderMode.singleHorizontalRTL =>
                            SinglePageReaderMode(
                              chapter: chapterData,
                              manga: data,
                              onPageChanged: onPageChanged,
                              initialOverlayVisible: initialOverlayVisible,
                              navigation: navigation,
                              beforeChapterChange: flushReadingProgress,
                              onChapterChangeCommitted:
                                  markChapterChangeCommitted,
                              showReaderLayoutAnimation:
                                  showReaderLayoutAnimation,
                              chapterPages: chapterPagesData,
                            ),
                          ReaderMode.continuousHorizontalLTR =>
                            ContinuousReaderMode(
                              chapter: chapterData,
                              manga: data,
                              onPageChanged: onPageChanged,
                              initialOverlayVisible: initialOverlayVisible,
                              navigation: navigation,
                              beforeChapterChange: flushReadingProgress,
                              onChapterChangeCommitted:
                                  markChapterChangeCommitted,
                              showReaderLayoutAnimation:
                                  showReaderLayoutAnimation,
                              chapterPages: chapterPagesData,
                            ),
                          ReaderMode.continuousHorizontalRTL =>
                            ContinuousReaderMode(
                              chapter: chapterData,
                              manga: data,
                              onPageChanged: onPageChanged,
                              initialOverlayVisible: initialOverlayVisible,
                              navigation: navigation,
                              beforeChapterChange: flushReadingProgress,
                              onChapterChangeCommitted:
                                  markChapterChangeCommitted,
                              showReaderLayoutAnimation:
                                  showReaderLayoutAnimation,
                              chapterPages: chapterPagesData,
                            ),
                          ReaderMode.singleHorizontalLTR =>
                            SinglePageReaderMode(
                              chapter: chapterData,
                              manga: data,
                              onPageChanged: onPageChanged,
                              initialOverlayVisible: initialOverlayVisible,
                              navigation: navigation,
                              beforeChapterChange: flushReadingProgress,
                              onChapterChangeCommitted:
                                  markChapterChangeCommitted,
                              chapterPages: chapterPagesData,
                            ),
                          ReaderMode.continuousVertical => ContinuousReaderMode(
                              chapter: chapterData,
                              manga: data,
                              onPageChanged: onPageChanged,
                              initialOverlayVisible: initialOverlayVisible,
                              navigation: navigation,
                              beforeChapterChange: flushReadingProgress,
                              onChapterChangeCommitted:
                                  markChapterChangeCommitted,
                              showSeparator: true,
                              showReaderLayoutAnimation:
                                  showReaderLayoutAnimation,
                              chapterPages: chapterPagesData,
                            ),
                          ReaderMode.webtoon => ContinuousReaderMode(
                              chapter: chapterData,
                              manga: data,
                              onPageChanged: onPageChanged,
                              initialOverlayVisible: initialOverlayVisible,
                              navigation: navigation,
                              beforeChapterChange: flushReadingProgress,
                              onChapterChangeCommitted:
                                  markChapterChangeCommitted,
                              showReaderLayoutAnimation:
                                  showReaderLayoutAnimation,
                              chapterPages: chapterPagesData,
                            ),
                          ReaderMode.defaultReader => ContinuousReaderMode(
                              chapter: chapterData,
                              manga: data,
                              onPageChanged: onPageChanged,
                              initialOverlayVisible: initialOverlayVisible,
                              navigation: navigation,
                              beforeChapterChange: flushReadingProgress,
                              onChapterChangeCommitted:
                                  markChapterChangeCommitted,
                              showReaderLayoutAnimation:
                                  showReaderLayoutAnimation,
                              chapterPages: chapterPagesData,
                            ),
                        };
                        return KeyedSubtree(
                          key: ValueKey(
                            'reader-content-${chapterData.id}-'
                            '${resolvedReaderMode.name}',
                          ),
                          child: reader,
                        );
                      },
                    );
                  },
                  refresh: () => ref.refresh(chapterProviderWithIndex.future),
                  addScaffoldWrapper: true,
                );
              },
              addScaffoldWrapper: true,
              refresh: () => ref.refresh(mangaProvider.future),
            ),
          ),
        ),
      ),
    );
  }
}
