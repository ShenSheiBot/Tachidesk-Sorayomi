import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_progress_debouncer.dart';

void main() {
  group('ReaderProgressDebouncer', () {
    test('flush persists the pending page before reader exit', () async {
      final savedPages = <int>[];
      final debouncer = ReaderProgressDebouncer(
        delay: const Duration(days: 1),
        onSave: (page) async {
          savedPages.add(page);
          return true;
        },
      );

      debouncer.schedule(7);
      await debouncer.flush();

      expect(savedPages, [7]);
      debouncer.dispose();
    });

    test('a newer page replaces the pending debounced page', () async {
      final savedPages = <int>[];
      final debouncer = ReaderProgressDebouncer(
        delay: const Duration(days: 1),
        onSave: (page) async {
          savedPages.add(page);
          return true;
        },
      );

      debouncer
        ..schedule(3)
        ..schedule(4);
      await debouncer.flush();

      expect(savedPages, [4]);
      debouncer.dispose();
    });

    test('dispose discards work owned by a removed reader', () async {
      final savedPages = <int>[];
      final debouncer = ReaderProgressDebouncer(
        delay: const Duration(days: 1),
        onSave: (page) async {
          savedPages.add(page);
          return true;
        },
      );

      debouncer
        ..schedule(5)
        ..dispose();
      await debouncer.flush();

      expect(savedPages, isEmpty);
    });

    test('serializes saves and flush waits for an in-flight save', () async {
      final firstSaveStarted = Completer<void>();
      final releaseFirstSave = Completer<void>();
      final savedPages = <int>[];
      final debouncer = ReaderProgressDebouncer(
        delay: const Duration(days: 1),
        onSave: (page) async {
          savedPages.add(page);
          if (page == 6) {
            firstSaveStarted.complete();
            await releaseFirstSave.future;
          }
          return true;
        },
      );

      debouncer.schedule(6);
      final firstFlush = debouncer.flush();
      await firstSaveStarted.future;

      final terminalSave = debouncer.saveNow(9);
      final secondFlush = debouncer.flush();
      await Future<void>.delayed(Duration.zero);
      expect(savedPages, [6]);

      releaseFirstSave.complete();
      await Future.wait([firstFlush, terminalSave, secondFlush]);

      expect(savedPages, [6, 9]);
      debouncer.dispose();
    });

    test('flushAndClose rejects pages scheduled during exit', () async {
      final savedPages = <int>[];
      final debouncer = ReaderProgressDebouncer(
        delay: const Duration(days: 1),
        onSave: (page) async {
          savedPages.add(page);
          return true;
        },
      );

      debouncer.schedule(2);
      final exitFlush = debouncer.flushAndClose();
      debouncer.schedule(3);
      await exitFlush;

      expect(savedPages, [2]);
      expect(await debouncer.saveNow(4), isFalse);
      debouncer.dispose();
    });
  });
}
