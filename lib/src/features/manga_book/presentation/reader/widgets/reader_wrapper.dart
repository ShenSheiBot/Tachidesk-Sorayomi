// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../constants/app_constants.dart';
import '../../../../../constants/app_sizes.dart';
import '../../../../../constants/db_keys.dart';
import '../../../../../constants/enum.dart';
import '../../../../../routes/router_config.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/launch_url_in_web.dart';
import '../../../../../utils/misc/toast/toast.dart';
import '../../../../../widgets/popup_widgets/radio_list_popup.dart';
import '../../../../settings/presentation/reader/widgets/reader_invert_tap_tile/reader_invert_tap_tile.dart';
import '../../../../settings/presentation/reader/widgets/reader_last_page_swipe_tile/reader_last_page_swipe_tile.dart';
import '../../../../settings/presentation/reader/widgets/reader_magnifier_size_slider/reader_magnifier_size_slider.dart';
import '../../../../settings/presentation/reader/widgets/reader_navigation_layout_tile/reader_navigation_layout_tile.dart';
import '../../../../settings/presentation/reader/widgets/reader_padding_slider/reader_padding_slider.dart';
import '../../../../settings/presentation/reader/widgets/reader_swipe_toggle_tile/reader_swipe_chapter_toggle_tile.dart';
import '../../../../settings/presentation/reader/widgets/reader_volume_tap_invert_tile/reader_volume_tap_invert_tile.dart';
import '../../../../settings/presentation/reader/widgets/reader_volume_tap_tile/reader_volume_tap_tile.dart';
import '../../../data/manga_book/manga_book_repository.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/chapter_batch/chapter_batch_model.dart';
import '../../../domain/chapter_page/chapter_page_model.dart';
import '../../../domain/manga/manga_model.dart';
import '../../../widgets/chapter_actions/single_chapter_action_icon.dart';
import '../../manga_details/controller/manga_details_controller.dart';
import '../controller/reader_controller.dart';
import '../navigation/reader_keyboard_shortcuts.dart';
import '../navigation/reader_navigation.dart';
import 'directional_swipe_gesture_handler.dart';
import 'reader_navigation_layout/reader_navigation_layout.dart';
import 'reader_progress_controls.dart';

typedef ReaderContentBuilder = Widget Function(
  ReaderContentNavigation contentNavigation,
);

final class ReaderContentNavigation {
  const ReaderContentNavigation({
    required this.onCommand,
    required this.previousChapter,
    required this.nextChapter,
    required this.showChapterButtons,
  });

  final ValueChanged<ReaderCommand> onCommand;
  final ChapterDto? previousChapter;
  final ChapterDto? nextChapter;
  final bool showChapterButtons;
}

class ReaderWrapper extends HookConsumerWidget {
  const ReaderWrapper({
    super.key,
    required this.childBuilder,
    required this.manga,
    required this.chapter,
    required this.navigationState,
    required this.initialOverlayVisible,
    required this.onStepPage,
    required this.onJumpToPage,
    required this.beforeChapterChange,
    required this.onChapterChangeCommitted,
    required this.navigation,
    this.showReaderLayoutAnimation = false,
    required this.chapterPages,
  });
  final ReaderContentBuilder childBuilder;
  final MangaDto manga;
  final ChapterDto chapter;
  final ReaderPageStep onStepPage;
  final ReaderPageJump onJumpToPage;
  final AsyncCallback beforeChapterChange;
  final VoidCallback onChapterChangeCommitted;
  final ValueListenable<ReaderNavigationState> navigationState;
  final bool initialOverlayVisible;
  final ResolvedReaderNavigation navigation;
  final bool showReaderLayoutAnimation;
  final ChapterPagesDto chapterPages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewport = useValueListenable(navigationState);
    final nextPrevChapterPair = ref.watch(
      readerChapterNeighborsProvider(
        mangaId: manga.id,
        chapterId: chapter.id,
      ),
    );
    final bool volumeTap = ref.watch(volumeTapProvider).ifNull();
    final bool volumeTapInvert = ref.watch(volumeTapInvertProvider).ifNull();
    final bool invertTap = ref.watch(invertTapProvider).ifNull();

    final double localMangaReaderPadding =
        ref.watch(readerPaddingKeyProvider) ?? DBKeys.readerPadding.initial;

    final bool readerSwipeChapterToggle =
        ref.watch(swipeChapterToggleProvider) ?? DBKeys.swipeToggle.initial;

    final bool lastPageSwipeEnabled = ref.watch(lastPageSwipeEnabledProvider) ??
        DBKeys.lastPageSwipeEnabled.initial;

    final double localMangaReaderMagnifierSize =
        ref.watch(readerMagnifierSizeKeyProvider) ??
            DBKeys.readerMagnifierSize.initial;

    final visibility = useState(initialOverlayVisible);
    final mangaReaderPadding =
        useState(manga.metaData.readerPadding ?? localMangaReaderPadding);
    final mangaReaderMagnifierSize = useState(
      manga.metaData.readerMagnifierSize ?? localMangaReaderMagnifierSize,
    );

    final mangaReaderMode =
        manga.metaData.readerMode ?? ReaderMode.defaultReader;
    final mangaReaderNavigationLayout = manga.metaData.readerNavigationLayout ??
        ReaderNavigationLayout.defaultNavigation;
    final defaultReaderNavigationLayout =
        ref.watch(readerNavigationLayoutKeyProvider);
    final resolvedReaderNavigationLayout =
        mangaReaderNavigationLayout == ReaderNavigationLayout.defaultNavigation
            ? defaultReaderNavigationLayout ?? ReaderNavigationLayout.disabled
            : mangaReaderNavigationLayout;

    final showReaderModePopup = useCallback(
      () => showDialog(
        context: context,
        builder: (context) => RadioListPopup<ReaderMode>(
          optionList: ReaderMode.values,
          getOptionTitle: (value) => value.toLocale(context),
          value: mangaReaderMode,
          title: context.l10n.readerMode,
          onChange: (enumValue) async {
            if (context.mounted) Navigator.pop(context);
            await AsyncValue.guard(
              () => ref.read(mangaBookRepositoryProvider).patchMangaMeta(
                    mangaId: manga.id,
                    key: MangaMetaKeys.readerMode.key,
                    value: enumValue.name,
                  ),
            );
            ref.invalidate(mangaWithIdProvider(mangaId: manga.id));
          },
        ),
      ),
      [mangaReaderMode],
    );

    final showReaderNavigationLayoutPopup = useCallback(
      () => showDialog(
        context: context,
        builder: (context) => RadioListPopup<ReaderNavigationLayout>(
          optionList: ReaderNavigationLayout.values,
          getOptionTitle: (value) => value.toLocale(context),
          title: context.l10n.readerNavigationLayout,
          value: mangaReaderNavigationLayout,
          onChange: (enumValue) async {
            if (context.mounted) Navigator.pop(context);
            await AsyncValue.guard(
              () => ref.read(mangaBookRepositoryProvider).patchMangaMeta(
                    mangaId: manga.id,
                    key: MangaMetaKeys.readerNavigationLayout.key,
                    value: enumValue.name,
                  ),
            );
            ref.invalidate(mangaWithIdProvider(mangaId: manga.id));
          },
        ),
      ),
      [mangaReaderNavigationLayout],
    );

    useEffect(() {
      if (!visibility.value) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      return null;
    }, [visibility.value]);

    final actualPageCount = chapterPages.pages.length;
    final coordinator = useMemoized(ReaderNavigationCoordinator.new);
    useEffect(() => coordinator.dispose, [coordinator]);

    final changeChapter = useCallback<ReaderChapterChange>((direction) async {
      final targetChapter = direction == ReadingDirection.forward
          ? nextPrevChapterPair?.next
          : nextPrevChapterPair?.previous;
      if (targetChapter == null) return false;

      await beforeChapterChange();
      if (!context.mounted) return false;
      onChapterChangeCommitted();
      final transition = navigation.chapterTransition(direction);
      ReaderRoute(
        mangaId: manga.id,
        chapterId: targetChapter.id,
        transVertical: transition.isVertical,
        toPrev: transition.fromNegativeDirection,
        fromReaderChapterNavigation: true,
        openAtEnd: transition.openAtEnd,
      ).pushReplacement(context);
      return true;
    }, [
      nextPrevChapterPair,
      manga.id,
      navigation,
      beforeChapterChange,
      onChapterChangeCommitted,
    ]);

    final bindings = ReaderNavigationBindings(
      state: navigationState,
      stepPage: onStepPage,
      jumpToPage: onJumpToPage,
      changeChapter: changeChapter,
    );
    final bindingsRef = useRef(bindings)..value = bindings;
    final dispatch = useCallback((ReaderCommand command) {
      unawaited(coordinator.dispatch(command, bindingsRef.value));
    }, [coordinator]);
    final contentNavigation = ReaderContentNavigation(
      onCommand: dispatch,
      previousChapter: nextPrevChapterPair?.previous,
      nextChapter: nextPrevChapterPair?.next,
      showChapterButtons:
          resolvedReaderNavigationLayout == ReaderNavigationLayout.disabled,
    );

    useEffect(() {
      StreamSubscription<HardwareButton>? subscription;
      if (volumeTap) {
        subscription = FlutterAndroidVolumeKeydown.stream.listen(
          (event) => (switch (event) {
            HardwareButton.volume_up => dispatch(
                StepReaderPage(
                  volumeTapInvert
                      ? ReadingDirection.forward
                      : ReadingDirection.backward,
                ),
              ),
            HardwareButton.volume_down => dispatch(
                StepReaderPage(
                  volumeTapInvert
                      ? ReadingDirection.backward
                      : ReadingDirection.forward,
                ),
              ),
          }),
        );
      }
      return () => subscription?.cancel();
    }, [volumeTap, volumeTapInvert, dispatch]);

    return Theme(
      data: context.theme.copyWith(
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: visibility.value
            ? AppBar(
                title: ListTile(
                  title: (manga.title).isNotBlank
                      ? Text(
                          manga.title,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  subtitle: (chapter.name).isNotBlank
                      ? Text(
                          chapter.name,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                ),
                elevation: 0,
                actions: [
                  chapter.realUrl.isBlank
                      ? const SizedBox.shrink()
                      : IconButton(
                          onPressed: () async {
                            launchUrlInWeb(
                              context,
                              (chapter.realUrl ?? ""),
                              ref.read(toastProvider),
                            );
                          },
                          icon: const Icon(Icons.public_rounded),
                        )
                ],
              )
            : null,
        extendBodyBehindAppBar: true,
        extendBody: true,
        endDrawerEnableOpenDragGesture: false,
        endDrawer: Drawer(
          width: kDrawerWidth,
          shape: const RoundedRectangleBorder(),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.close_rounded),
                onTap: context.pop,
              ),
              ListTile(
                style: ListTileStyle.drawer,
                leading: const Icon(Icons.app_settings_alt_outlined),
                title: Text(context.l10n.readerMode),
                subtitle: Text(mangaReaderMode.toLocale(context)),
                onTap: () {
                  context.pop();
                  showReaderModePopup();
                },
              ),
              ListTile(
                style: ListTileStyle.drawer,
                leading: const Icon(Icons.touch_app_rounded),
                title: Text(context.l10n.readerNavigationLayout),
                subtitle: Text(mangaReaderNavigationLayout.toLocale(context)),
                onTap: () {
                  context.pop();
                  showReaderNavigationLayoutPopup();
                },
              ),
              AsyncReaderPaddingSlider(
                readerPadding: mangaReaderPadding,
                onChanged: (value) {
                  AsyncValue.guard(
                    () => ref.read(mangaBookRepositoryProvider).patchMangaMeta(
                          mangaId: manga.id,
                          key: MangaMetaKeys.readerPadding.key,
                          value: value,
                        ),
                  );
                  ref.invalidate(mangaWithIdProvider(mangaId: manga.id));
                },
              ),
              AsyncReaderMagnifierSizeSlider(
                readerMagnifierSize: mangaReaderMagnifierSize,
                onChanged: (value) {
                  AsyncValue.guard(
                    () => ref.read(mangaBookRepositoryProvider).patchMangaMeta(
                          mangaId: manga.id,
                          key: MangaMetaKeys.readerMagnifierSize.key,
                          value: value,
                        ),
                  );
                  ref.invalidate(mangaWithIdProvider(mangaId: manga.id));
                },
              ),
            ],
          ),
        ),
        bottomSheet: visibility.value
            ? ExcludeFocus(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReaderProgressControls(
                      navigation: navigation,
                      currentPageIndex: viewport.displayPageIndex,
                      pageCount: actualPageCount,
                      onPageChanged: (index) =>
                          dispatch(JumpToReaderPage(index)),
                      onPreviousChapter: nextPrevChapterPair?.previous != null
                          ? () => dispatch(
                                const ChangeReaderChapter(
                                  ReadingDirection.backward,
                                ),
                              )
                          : null,
                      onNextChapter: nextPrevChapterPair?.next != null
                          ? () => dispatch(
                                const ChangeReaderChapter(
                                  ReadingDirection.forward,
                                ),
                              )
                          : null,
                      previousChapterTooltip: context.l10n.previousChapter(
                        nextPrevChapterPair?.previous?.name ?? '',
                      ),
                      nextChapterTooltip: context.l10n.nextChapter(
                        nextPrevChapterPair?.next?.name ?? '',
                      ),
                    ),
                    const Gap(8),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: KRadius.r8.radius,
                        ),
                      ),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: KEdgeInsets.h16v8.size,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SingleChapterActionIcon(
                              icon: chapter.isBookmarked
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
                              chapterId: chapter.id,
                              change: ChapterChange(
                                  isBookmarked: !chapter.isBookmarked),
                              refresh: () => ref.refresh(
                                  chapterProvider(chapterId: chapter.id)
                                      .future),
                            ),
                            IconButton(
                              icon: const Icon(Icons.app_settings_alt_outlined),
                              onPressed: () => showReaderModePopup(),
                            ),
                            Builder(builder: (context) {
                              return IconButton(
                                onPressed: () =>
                                    Scaffold.of(context).openEndDrawer(),
                                icon: const Icon(Icons.settings_rounded),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : null,
        body: Shortcuts.manager(
          manager: readerShortcutManager(navigation),
          child: Actions(
            actions: {
              StepReaderPageIntent: CallbackAction<StepReaderPageIntent>(
                onInvoke: (intent) {
                  dispatch(StepReaderPage(intent.direction));
                  return null;
                },
              ),
              ChangeReaderChapterIntent:
                  CallbackAction<ChangeReaderChapterIntent>(
                onInvoke: (intent) {
                  dispatch(ChangeReaderChapter(intent.direction));
                  return null;
                },
              ),
              ToggleReaderOverlayIntent:
                  CallbackAction<ToggleReaderOverlayIntent>(
                onInvoke: (intent) {
                  visibility.value = !visibility.value;
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Listener(
                child: RepaintBoundary(
                  child: ReaderView(
                    toggleVisibility: () =>
                        visibility.value = !visibility.value,
                    navigation: navigation,
                    mangaReaderPadding: mangaReaderPadding.value,
                    mangaReaderMagnifierSize: mangaReaderMagnifierSize.value,
                    onCommand: dispatch,
                    mangaReaderNavigationLayout: resolvedReaderNavigationLayout,
                    invertTap: invertTap,
                    readerSwipeChapterToggle: readerSwipeChapterToggle,
                    lastPageSwipeEnabled: lastPageSwipeEnabled,
                    showReaderLayoutAnimation: showReaderLayoutAnimation,
                    child: childBuilder(contentNavigation),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderView extends HookWidget {
  const ReaderView({
    super.key,
    required this.toggleVisibility,
    required this.navigation,
    required this.mangaReaderPadding,
    required this.mangaReaderMagnifierSize,
    required this.onCommand,
    required this.mangaReaderNavigationLayout,
    required this.invertTap,
    required this.readerSwipeChapterToggle,
    required this.lastPageSwipeEnabled,
    required this.child,
    this.showReaderLayoutAnimation = false,
  });

  final VoidCallback toggleVisibility;
  final ResolvedReaderNavigation navigation;
  final double mangaReaderPadding;
  final double mangaReaderMagnifierSize;
  final ValueChanged<ReaderCommand> onCommand;
  final ReaderNavigationLayout mangaReaderNavigationLayout;
  final bool invertTap;
  final bool readerSwipeChapterToggle;
  final bool lastPageSwipeEnabled;
  final bool showReaderLayoutAnimation;
  final Widget child;

  /// Gesture handling extracted for better performance and maintainability.
  /// This widget focuses on:
  /// - Magnification handling
  /// - Navigation layout overlay
  /// - Basic UI state management

  @override
  Widget build(BuildContext context) {
    final showMagnification = useState(false);
    final dragGesturePosition = useState(Offset.zero);
    final positionOffset = kMagnifierPosition(
      dragGesturePosition.value,
      context.mediaQuerySize,
      mangaReaderMagnifierSize,
    );

    // Build the core reading content wrapped with padding
    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.height *
            (navigation.axis != Axis.vertical ? mangaReaderPadding : 0),
        horizontal: context.width *
            (navigation.axis == Axis.vertical ? mangaReaderPadding : 0),
      ),
      child: child,
    );

    content = DirectionalSwipeGestureHandler(
      onTap: toggleVisibility,
      onLongPressStart: (details) {
        dragGesturePosition.value = details.localPosition;
        showMagnification.value = true;
      },
      onLongPressEnd: (details) {
        showMagnification.value = false;
      },
      onLongPressMoveUpdate: (details) =>
          dragGesturePosition.value = details.localPosition,
      scrollDirection: navigation.axis,
      readerSwipeChapterToggle: readerSwipeChapterToggle,
      lastPageSwipeEnabled: lastPageSwipeEnabled,
      onChangeChapter: (direction) => onCommand(ChangeReaderChapter(direction)),
      child: content,
    );

    return Stack(
      children: [
        content,
        ReaderNavigationLayoutWidget(
          onNext: () => onCommand(
            const StepReaderPage(ReadingDirection.forward),
          ),
          onPrevious: () => onCommand(
            const StepReaderPage(ReadingDirection.backward),
          ),
          navigation: navigation,
          invertTap: invertTap,
          navigationLayout: mangaReaderNavigationLayout,
          showReaderLayoutAnimation: showReaderLayoutAnimation,
        ),
        if (showMagnification.value)
          Positioned(
            left: positionOffset.dx,
            top: positionOffset.dy,
            child: RawMagnifier(
              decoration: kMagnifierDecoration,
              size: kMagnifierSize * mangaReaderMagnifierSize,
              focalPointOffset: kMagnifierOffset(
                dragGesturePosition.value,
                context.mediaQuerySize,
                mangaReaderMagnifierSize,
              ),
              magnificationScale: 2,
              child: const ColoredBox(color: Color.fromARGB(8, 158, 158, 158)),
            ),
          ),
      ],
    );
  }
}
