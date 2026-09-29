import 'package:flutter_test/flutter_test.dart';
import 'package:graphql/client.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/domain/manga/manga_model.dart';

void main() {
  test('numeric reader padding is stored as manga metadata and read back',
      () async {
    final writes = <Map<String, dynamic>>[];
    final client = GraphQLClient(
      cache: GraphQLCache(),
      link: Link.function((request, [forward]) async* {
        writes.add(request.variables);
        yield Response(data: {'setMangaMeta': null}, response: {});
      }),
    );
    await MangaBookRepository(client).patchMangaMeta(
      mangaId: 42,
      key: MangaMetaKeys.readerPadding.key,
      value: 0.2,
    );
    final meta = writes.single['input']['meta'] as Map<String, dynamic>;
    expect(
        meta, {'mangaId': 42, 'key': 'flutter_readerPadding', 'value': '0.2'});
    expect(
        MangaMeta.fromJson({meta['key'] as String: meta['value']})
            .readerPadding,
        0.2);
  });
}
