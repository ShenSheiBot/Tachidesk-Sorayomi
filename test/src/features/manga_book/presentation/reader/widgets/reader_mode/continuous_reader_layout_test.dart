import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter/chapter_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/chapter_page/chapter_page_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/manga_model.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/controller/reader_controller.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_navigation.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/widgets/reader_mode/continuous_reader_mode.dart';
import 'package:tachidesk_sorayomi/src/global_providers/global_providers.dart';
import 'package:tachidesk_sorayomi/src/l10n/generated/app_localizations.dart';
import 'package:tachidesk_sorayomi/src/widgets/server_image.dart';

import '../reader_mouse_wheel_test.dart' show wheel;

void main() {
  for (final mode in [ReaderMode.continuousVertical, ReaderMode.webtoon]) {
    testWidgets('$mode joins image edges and scrolls both ways',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      // Seed decoded images, leaving the real ServerImage/list layout intact.
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 800, 200), Paint()..color = Colors.white);
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(800, 200));
      picture.dispose();
      for (var i = 0; i < 10; i++) {
        PaintingBinding.instance.imageCache.putIfAbsent(
          CachedNetworkImageProvider('http://127.0.0.1:4567/page-$i.png'),
          () => OneFrameImageStreamCompleter(
              Future.value(ImageInfo(image: image!.clone()))),
        );
      }
      image!.dispose();
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
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          readerChapterNeighborsProvider(mangaId: 1, chapterId: 1)
              .overrideWith((_) => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ContinuousReaderMode(
            manga: manga,
            chapter: chapter,
            chapterPages: ChapterPagesDto.fromJson({
              '__typename': 'FetchChapterPagesPayload',
              'chapter': {
                '__typename': 'ChapterType',
                'id': 1,
                'pageCount': 10
              },
              'pages': List.generate(10, (i) => '/page-$i.png'),
            }),
            initialOverlayVisible: false,
            navigation: ResolvedReaderNavigation.fromMode(mode),
            initialPage: 0,
            beforeChapterChange: () async {},
            onChapterChangeCommitted: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      final first = find.byType(ServerImage).at(0);
      final second = find.byType(ServerImage).at(1);
      expect(tester.getBottomLeft(first).dy, tester.getTopLeft(second).dy);
      expect(tester.getSize(first), const Size(800, 200));
      final initialTop = tester.getTopLeft(first).dy;
      await wheel(tester, 100);
      expect(tester.getTopLeft(first).dy, initialTop - 100);
      await wheel(tester, -100);
      expect(tester.getTopLeft(first).dy, initialTop);
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
    });
  }
}
