package com.example.power_share

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "generator_portal/platform")
            .setMethodCallHandler { call, result ->
                if (call.method == "openMail") {
                    try {
                        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_EMAIL))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "generator_portal/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareText") {
                    val text = call.argument<String>("text")
                    if (text.isNullOrBlank()) {
                        result.error("invalid", "نص المشاركة فارغ", null)
                    } else {
                        try {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(intent, "مشاركة الفاتورة"))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("unavailable", "تعذر فتح المشاركة", null)
                        }
                    }
                } else result.notImplemented()
            }
    }
}
