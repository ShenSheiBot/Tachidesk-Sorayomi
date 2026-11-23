// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../global_providers/global_providers.dart';

part 'reader_scroll_animation_tile.g.dart';

enum ReaderPageAnimation { none, slide, iReaderRipple }

const _animationKey = 'scrollAnimation';
const _rippleValue = 'iReaderRipple';
const _rippleChannel = MethodChannel('sorayomi/ireader_page_turn');

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> prepareIReaderRipple({
  required bool forward,
  required bool rightToLeft,
}) async {
  if (!_isAndroid) return;
  try {
    await _rippleChannel.invokeMethod<void>('prepare', {
      'forward': forward,
      'rightToLeft': rightToLeft,
    });
  } on PlatformException catch (error) {
    debugPrint('iReader ripple unavailable: $error');
  } on MissingPluginException {
    // The ordinary page jump is also available without the vendor bridge.
  }
}

@riverpod
class ReaderScrollAnimation extends _$ReaderScrollAnimation {
  @override
  ReaderPageAnimation build() {
    final value = ref.watch(sharedPreferencesProvider).get(_animationKey);
    return switch (value) {
      false => ReaderPageAnimation.none,
      _rippleValue => ReaderPageAnimation.iReaderRipple,
      _ => ReaderPageAnimation.slide,
    };
  }

  void update(ReaderPageAnimation value) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (value == ReaderPageAnimation.iReaderRipple) {
      prefs.setString(_animationKey, _rippleValue);
    } else {
      prefs.setBool(_animationKey, value == ReaderPageAnimation.slide);
    }
    state = value;
  }
}

class ReaderScrollAnimationTile extends ConsumerWidget {
  const ReaderScrollAnimationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animation = ref.watch(readerScrollAnimationProvider);
    final update = ref.read(readerScrollAnimationProvider.notifier).update;
    return ListTile(
      leading: const Icon(Icons.animation_rounded),
      title: Text(context.l10n.readerScrollAnimation),
      trailing: DropdownButton<ReaderPageAnimation>(
        value: animation,
        onChanged: (value) {
          if (value != null) update(value);
        },
        items: [
          DropdownMenuItem(
            value: ReaderPageAnimation.none,
            child: Text(context.l10n.readerPageAnimationNone),
          ),
          DropdownMenuItem(
            value: ReaderPageAnimation.slide,
            child: Text(context.l10n.readerPageAnimationSlide),
          ),
          if (_isAndroid || animation == ReaderPageAnimation.iReaderRipple)
            DropdownMenuItem(
              value: ReaderPageAnimation.iReaderRipple,
              child: Text(context.l10n.readerPageAnimationIReader),
            ),
        ],
      ),
    );
  }
}
