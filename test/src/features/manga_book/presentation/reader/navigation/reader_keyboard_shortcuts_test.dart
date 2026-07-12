import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachidesk_sorayomi/src/constants/enum.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_keyboard_shortcuts.dart';
import 'package:tachidesk_sorayomi/src/features/manga_book/presentation/reader/navigation/reader_navigation.dart';

void main() {
  group('readerShortcutManager', () {
    for (final mode in ReaderMode.values) {
      test('maps navigation keys for $mode', () {
        final navigation = ResolvedReaderNavigation.fromMode(mode);
        final shortcuts = readerShortcutManager(navigation).shortcuts;

        _expectStep(
          shortcuts[const SingleActivator(LogicalKeyboardKey.space)],
          ReadingDirection.forward,
        );
        _expectStep(
          shortcuts[
              const SingleActivator(LogicalKeyboardKey.space, shift: true)],
          ReadingDirection.backward,
        );
        expect(
          shortcuts[const SingleActivator(LogicalKeyboardKey.escape)],
          isA<ToggleReaderOverlayIntent>(),
        );

        if (navigation.axis == Axis.horizontal) {
          _expectStep(
            shortcuts[const SingleActivator(LogicalKeyboardKey.arrowLeft)],
            navigation.isHorizontalRtl
                ? ReadingDirection.forward
                : ReadingDirection.backward,
          );
          _expectStep(
            shortcuts[const SingleActivator(LogicalKeyboardKey.arrowRight)],
            navigation.isHorizontalRtl
                ? ReadingDirection.backward
                : ReadingDirection.forward,
          );
          _expectChapter(
            shortcuts[const SingleActivator(LogicalKeyboardKey.arrowUp)],
            ReadingDirection.forward,
          );
          _expectChapter(
            shortcuts[const SingleActivator(LogicalKeyboardKey.arrowDown)],
            ReadingDirection.backward,
          );
        } else {
          _expectChapter(
            shortcuts[const SingleActivator(LogicalKeyboardKey.arrowLeft)],
            ReadingDirection.backward,
          );
          _expectChapter(
            shortcuts[const SingleActivator(LogicalKeyboardKey.arrowRight)],
            ReadingDirection.forward,
          );
          _expectStep(
            shortcuts[const SingleActivator(LogicalKeyboardKey.arrowUp)],
            ReadingDirection.backward,
          );
          _expectStep(
            shortcuts[const SingleActivator(LogicalKeyboardKey.arrowDown)],
            ReadingDirection.forward,
          );
        }
      });
    }

    test('maps WASD aliases to the same intents as arrow keys', () {
      for (final mode in ReaderMode.values) {
        final shortcuts = readerShortcutManager(
          ResolvedReaderNavigation.fromMode(mode),
        ).shortcuts;

        _expectEquivalentIntent(
          shortcuts[const SingleActivator(LogicalKeyboardKey.arrowLeft)],
          shortcuts[const SingleActivator(LogicalKeyboardKey.keyA)],
        );
        _expectEquivalentIntent(
          shortcuts[const SingleActivator(LogicalKeyboardKey.arrowRight)],
          shortcuts[const SingleActivator(LogicalKeyboardKey.keyD)],
        );
        _expectEquivalentIntent(
          shortcuts[const SingleActivator(LogicalKeyboardKey.arrowUp)],
          shortcuts[const SingleActivator(LogicalKeyboardKey.keyW)],
        );
        _expectEquivalentIntent(
          shortcuts[const SingleActivator(LogicalKeyboardKey.arrowDown)],
          shortcuts[const SingleActivator(LogicalKeyboardKey.keyS)],
        );
      }
    });
  });
}

void _expectStep(Intent? intent, ReadingDirection direction) {
  expect(
    intent,
    isA<StepReaderPageIntent>().having(
      (intent) => intent.direction,
      'direction',
      direction,
    ),
  );
}

void _expectChapter(Intent? intent, ReadingDirection direction) {
  expect(
    intent,
    isA<ChangeReaderChapterIntent>().having(
      (intent) => intent.direction,
      'direction',
      direction,
    ),
  );
}

void _expectEquivalentIntent(Intent? first, Intent? second) {
  expect(second.runtimeType, first.runtimeType);
  switch (first) {
    case StepReaderPageIntent(:final direction):
      _expectStep(second, direction);
    case ChangeReaderChapterIntent(:final direction):
      _expectChapter(second, direction);
    default:
      fail('Expected a reader navigation intent, got $first');
  }
}
