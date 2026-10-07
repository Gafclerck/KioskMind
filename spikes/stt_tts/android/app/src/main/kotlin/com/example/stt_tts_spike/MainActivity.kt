package com.example.stt_tts_spike

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Answers the two questions the spike cannot answer from Dart: does the running
/// process hold INTERNET, and which phone is this.
///
/// The permission is read from the live process rather than the merged manifest,
/// because the merged manifest is exactly what is in doubt: the Flutter debug and
/// profile manifests add INTERNET for the tooling's own socket, and a build that
/// looks offline on paper can still reach the network.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasInternetPermission" -> result.success(
                        checkSelfPermission(android.Manifest.permission.INTERNET) ==
                            PackageManager.PERMISSION_GRANTED
                    )
                    "describe" -> result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "androidRelease" to Build.VERSION.RELEASE,
                            "sdkInt" to Build.VERSION.SDK_INT
                        )
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CHANNEL = "stt_tts_spike/device"
    }
}
