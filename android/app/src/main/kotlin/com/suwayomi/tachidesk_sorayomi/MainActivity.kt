package com.suwayomi.tachidesk_sorayomi

import android.view.KeyEvent
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownActivity
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownPlugin

class MainActivity : FlutterAndroidVolumeKeydownActivity() {
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        val isVolumeKey = keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
            keyCode == KeyEvent.KEYCODE_VOLUME_UP

        if (isVolumeKey &&
            event.repeatCount > 0 &&
            FlutterAndroidVolumeKeydownPlugin.eventSink != null
        ) {
            return true
        }

        return super.onKeyDown(keyCode, event)
    }
}
