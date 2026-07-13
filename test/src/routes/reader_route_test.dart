import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/routes/router_config.dart';

void main() {
  test('backward chapter entry carries the end-of-chapter landing intent', () {
    const route = ReaderRoute(
      mangaId: 10,
      chapterId: 20,
      fromReaderChapterNavigation: true,
      openAtEnd: true,
    );

    expect(route.location, contains('open-at-end=true'));
  });

  test('normal reader entry does not add an end landing query', () {
    const route = ReaderRoute(mangaId: 10, chapterId: 20);

    expect(route.location, isNot(contains('open-at-end')));
  });
}
