package com.suwayomi.tachidesk_sorayomi

import android.os.Build
import android.view.KeyEvent
import android.view.Surface
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownActivity
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownPlugin

class MainActivity : FlutterAndroidVolumeKeydownActivity() {
    private val epdc by lazy {
        if (Build.MANUFACTURER.equals("iReader", ignoreCase = true) ||
            Build.BRAND.equals("iReader", ignoreCase = true)
        ) {
            runCatching { Class.forName("android.eink.EPDCDevice") }.getOrNull()
        } else {
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "sorayomi/ireader_page_turn"
        ).setMethodCallHandler { call, result ->
            if (call.method != "prepare") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val device = epdc
            if (device == null) {
                result.error("unsupported", "iReader EPDC interface is unavailable", null)
                return@setMethodCallHandler
            }
            val forward = (call.argument<Boolean>("forward") == true) !=
                (call.argument<Boolean>("rightToLeft") == true)
            runCatching {
                @Suppress("DEPRECATION")
                val rotation = windowManager.defaultDisplay.rotation
                val direction = when (rotation) {
                    Surface.ROTATION_90 -> if (forward) 4 else 3
                    Surface.ROTATION_180 -> if (forward) 2 else 1
                    Surface.ROTATION_270 -> if (forward) 3 else 4
                    else -> if (forward) 1 else 2
                }
                val command = device.getMethod("nativePostCommand", String::class.java)
                val forceMode = try {
                    device.getMethod("setForceNextPostMode", Int::class.javaPrimitiveType)
                } catch (_: NoSuchMethodException) {
                    null
                }
                // SmartOS encodes standard speed as bit 6, combined with direction.
                command.invoke(null, "next-effect-type ${direction or 64}")
                forceMode?.invoke(null, 0x01000063)
            }.fold(
                onSuccess = { result.success(null) },
                onFailure = { result.error("unsupported", it.cause?.message ?: it.message, null) }
            )
        }
    }

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
