import 'package:flutter_test/flutter_test.dart';
import 'package:graphql/client.dart';
import 'package:tachidesk_sorayomi/src/features/history/data/history_repository.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/data/manga_book/manga_book_repository.dart';

void main() {
  test('fetch manga details sends the manga ID to fetchManga', () async {
    final requests = <Request>[];
    final client = GraphQLClient(
      cache: GraphQLCache(),
      link: Link.function((request, [forward]) async* {
        requests.add(request);
        yield Response(data: {
          '__typename': 'Mutation',
          'fetchManga': {
            '__typename': 'FetchMangaPayload',
            'manga': {'__typename': 'MangaType', 'id': 42},
          },
        }, response: {});
      }),
    );
    await MangaBookRepository(client).fetchMangaDetails(mangaId: 42);
    expect(
      requests.single.operation.document,
      gql(r'''
        mutation FetchMangaDetails($input: FetchMangaInput!) {
          fetchManga(input: $input) {
            manga { id __typename }
            __typename
          }
          __typename
        }
      '''),
    );
    expect(requests.single.variables, {
      'input': {'id': 42}
    });
  });

  test('reading history requests progress without an in-library condition',
      () async {
    final requests = <Request>[];
    final client = GraphQLClient(
      cache: GraphQLCache(),
      defaultPolicies:
          DefaultPolicies(query: Policies(fetch: FetchPolicy.noCache)),
      link: Link.function((request, [forward]) async* {
        requests.add(request);
        yield Response(data: {
          '__typename': 'Query',
          'chapters': {
            '__typename': 'ChapterNodeList',
            'nodes': [],
            'pageInfo': {
              '__typename': 'PageInfo',
              'hasNextPage': false,
              'hasPreviousPage': false,
            },
            'totalCount': 0,
          },
        }, response: {});
      }),
    );
    await HistoryRepository(client, MangaBookRepository(client))
        .getReadingHistory();
    final filter = requests.single.variables['filter'] as Map<String, dynamic>;
    expect(filter, isNot(contains('inLibrary')));
    expect(filter, contains('lastReadAt'));
    expect(filter, contains('or'));
  });
}
