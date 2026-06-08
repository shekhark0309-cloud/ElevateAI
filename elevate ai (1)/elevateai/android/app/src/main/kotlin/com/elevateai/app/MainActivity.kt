package com.elevateai.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.elevateai.app/native_nav"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openScreen") {
                pendingResult = result
                val route = call.argument<String>("route")
                val session = call.argument<Map<String, Any>>("session")?.let {
                    // Convert map to JSON string for importSession
                    kotlinx.serialization.json.buildJsonObject {
                        it.forEach { (k, v) ->
                            when(v) {
                                is String -> put(k, kotlinx.serialization.json.JsonPrimitive(v))
                                is Number -> put(k, kotlinx.serialization.json.JsonPrimitive(v))
                                is Boolean -> put(k, kotlinx.serialization.json.JsonPrimitive(v))
                            }
                        }
                    }.toString()
                }

                val intent = Intent(this, NativeHostActivity::class.java).apply {
                    putExtra("route", route)
                    putExtra("session", session)
                }
                startActivityForResult(intent, 1001)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001) {
            val resultMap = mutableMapOf<String, Any?>()
            data?.extras?.let { bundle ->
                for (key in it.keySet()) {
                    resultMap[key] = it.get(key)
                }
            }
            pendingResult?.success(resultMap)
            pendingResult = null
        }
    }
}
