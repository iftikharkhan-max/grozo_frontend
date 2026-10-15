package com.iftikhar.grozo

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tells the app whether a Google Maps API key was built in, so it can
        // use Google Maps or fall back to OpenStreetMap.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "grozo/config")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasMapsKey" -> {
                        val key = try {
                            packageManager
                                .getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                                .metaData?.getString("com.google.android.geo.API_KEY")
                        } catch (e: Exception) {
                            null
                        }
                        result.success(!key.isNullOrBlank())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
