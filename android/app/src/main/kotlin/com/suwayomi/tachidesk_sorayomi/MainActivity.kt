package com.suwayomi.tachidesk_sorayomi

import android.os.Build
import android.view.KeyEvent
import android.view.Surface
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownActivity
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownPlugin

class MainActivity : FlutterAndroidVolumeKeydownActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "sorayomi/ireader_page_turn"
        ).setMethodCallHandler { call, result ->
            if (call.method != "prepare") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            var stage = "check iReader brand"
            var device: Class<*>? = null
            val model = "${Build.MANUFACTURER} / ${Build.BRAND} / ${Build.MODEL}"
            val forward = (call.argument<Boolean>("forward") == true) !=
                (call.argument<Boolean>("rightToLeft") == true)
            runCatching {
                check(Build.MANUFACTURER.equals("iReader", ignoreCase = true) ||
                    Build.BRAND.equals("iReader", ignoreCase = true))
                stage = "load android.eink.EPDCDevice"
                val epdc = Class.forName("android.eink.EPDCDevice")
                device = epdc
                @Suppress("DEPRECATION")
                val rotation = windowManager.defaultDisplay.rotation
                val direction = when (rotation) {
                    Surface.ROTATION_90 -> if (forward) 4 else 3
                    Surface.ROTATION_180 -> if (forward) 2 else 1
                    Surface.ROTATION_270 -> if (forward) 3 else 4
                    else -> if (forward) 1 else 2
                }
                stage = "find nativePostCommand(String)"
                val command = epdc.getMethod("nativePostCommand", String::class.java)
                val forceMode = try {
                    epdc.getMethod("setForceNextPostMode", Int::class.javaPrimitiveType)
                } catch (_: NoSuchMethodException) {
                    null
                }
                val speed = requireNotNull(call.argument<Int>("speed"))
                val effect = direction or speed
                stage = "invoke nativePostCommand ($effect)"
                val posted = command.invoke(null, "next-effect-type $effect")
                stage = "invoke setForceNextPostMode"
                val forced = forceMode?.invoke(null, 0x01000063)
                val forceResult = if (forceMode == null) "method absent" else "returned $forced"
                "$model\nEffect: $effect\nnativePostCommand returned $posted\nForce mode: $forceResult"
            }.fold(
                onSuccess = { result.success(it) },
                onFailure = { error ->
                    val cause = error.cause ?: error
                    val methods = runCatching {
                        device?.declaredMethods.orEmpty()
                            .filter { it.name.contains("post", true) || it.name.contains("force", true) }
                            .joinToString("\n") { it.toGenericString() }
                    }.getOrDefault("")
                    result.success("$model\nFailed at: $stage\n$cause\n$methods")
                }
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
