import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql/client.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter/chapter_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/chapter_page_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/graphql/__generated__/fragment.graphql.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/manga_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/manga_details/controller/manga_details_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/controller/reader_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_navigation.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_wrapper.dart';
import 'package:tachidesk_sorayomi/src/features/settings/presentation/reader/widgets/reader_padding_slider/reader_padding_slider.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';

class _DelayedPaddingRepository extends MangaBookRepository {
  _DelayedPaddingRepository(this.manga)
      : super(GraphQLClient(
            cache: GraphQLCache(),
            link: Link.function((request, [forward]) async* {})));
  MangaDto manga;
  final saved = Completer<void>();
  int reads = 0;
  bool written = false;
  @override
  Future<MangaDto?> getManga({required int mangaId}) async {
    reads++;
    return manga;
  }

  @override
  Future<void> patchMangaMeta(
      {required int mangaId,
      required String key,
      required dynamic value}) async {
    await saved.future;
    manga = manga.copyWith(
        meta: [Fragment$MangaDto$meta(key: key, value: value.toString())]);
    written = true;
  }
}

void main() {
  testWidgets('padding previews immediately and saves on release or reset',
      (tester) async {
    final padding = ValueNotifier(0.1);
    addTearDown(padding.dispose);
    final saves = <double>[];
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: ValueListenableBuilder<double>(
        valueListenable: padding,
        builder: (_, value, __) => AsyncReaderPaddingSlider(
          readerPadding: padding,
          onChanged: saves.add,
        ),
      )),
    )));
    final control = tester.widget<Slider>(find.byType(Slider));
    control.onChanged!(0.2);
    expect(padding.value, 0.2);
    expect(saves, isEmpty);
    control.onChangeEnd!(0.2);
    expect(saves, [0.2]);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(padding.value, 0);
    expect(saves, [0.2, 0]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'chapter change waits for padding save and reads the persisted value',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final manga = MangaDto.fromJson({
      '__typename': 'MangaType',
      'id': 1,
      'title': 'Fixture',
      'url': '',
      'downloadCount': 0,
      'genre': <String>[],
      'inLibrary': true,
      'inLibraryAt': '0',
      'initialized': true,
      'meta': <Object>[],
      'sourceId': '1',
      'status': 'ONGOING',
      'unreadCount': 1,
      'updateStrategy': 'ALWAYS_UPDATE',
    });
    final chapter = ChapterDto(
      id: 1,
      mangaId: 1,
      name: 'Chapter',
      chapterNumber: 1,
      fetchedAt: '0',
      isBookmarked: false,
      isDownloaded: false,
      isRead: false,
      lastPageRead: 0,
      lastReadAt: '0',
      pageCount: 10,
      sourceOrder: 1,
      uploadDate: '0',
      url: '',
      meta: [],
    );

    final repo = _DelayedPaddingRepository(manga);
    final container = ProviderContainer(overrides: [
      mangaBookRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      readerChapterNeighborsProvider(mangaId: 1, chapterId: 1)
          .overrideWith((_) => (next: chapter.copyWith(id: 2), previous: null)),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(mangaWithIdProvider(mangaId: 1), (_, __) {});
    addTearDown(subscription.close);
    await container.read(mangaWithIdProvider(mangaId: 1).future);
    final state = ValueNotifier(const ReaderNavigationState(
        displayPageIndex: 0, atStart: true, atEnd: false, isBusy: false));
    addTearDown(state.dispose);
    late ReaderContentNavigation navigation;
    var chapterCommitted = false;
    final router = GoRouter(initialLocation: '/manga/1/chapter/1', routes: [
      GoRoute(
          path: '/manga/:mangaId/chapter/:chapterId',
          builder: (_, route) {
            if (route.pathParameters['chapterId'] == '2') {
              return Consumer(
                  builder: (_, ref, __) => Text(
                        'padding:${ref.watch(mangaWithIdProvider(mangaId: 1)).valueOrNull?.metaData.readerPadding}',
                      ));
            }
            return ReaderWrapper(
              manga: manga,
              chapter: chapter,
              chapterPages: ChapterPagesDto.fromJson({
                '__typename': 'FetchChapterPagesPayload',
                'chapter': {
                  '__typename': 'ChapterType',
                  'id': 1,
                  'pageCount': 0
                },
                'pages': <String>[]
              }),
              childBuilder: (value) {
                navigation = value;
                return const SizedBox.expand();
              },
              navigationState: state,
              initialOverlayVisible: true,
              onStepPage: (_) async => ReaderPageStepResult.moved,
              onJumpToPage: (_) async {},
              beforeChapterChange: () async {},
              onChapterChangeCommitted: () {
                chapterCommitted = true;
              },
              navigation: ResolvedReaderNavigation.fromMode(
                  ReaderMode.singleHorizontalLTR),
            );
          }),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        )));
    await tester.pump();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openEndDrawer();
    await tester.pumpAndSettle();
    final slider = find.descendant(
        of: find.byType(AsyncReaderPaddingSlider),
        matching: find.byType(Slider));
    final control = tester.widget<Slider>(slider);
    control.onChanged!(0.2);
    control.onChangeEnd?.call(0.2);
    scaffold.closeEndDrawer();
    navigation.onCommand(const ChangeReaderChapter(ReadingDirection.forward));
    await tester.pump();
    expect(chapterCommitted, isFalse,
        reason: 'Do not replace the chapter while padding is still saving');
    repo.saved.complete();
    await tester.pumpAndSettle();
    expect(repo.written, isTrue);
    expect(chapterCommitted, isTrue);
    expect(find.text('padding:0.2'), findsOneWidget);
    expect(repo.reads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
