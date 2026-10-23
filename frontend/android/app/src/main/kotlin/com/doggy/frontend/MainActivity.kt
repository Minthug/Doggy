package com.doggy.frontend

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.doggy.frontend/dog_image_validator"
        ).setMethodCallHandler { call, result ->
            if (call.method != "validate") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            if (path.isNullOrBlank() || !File(path).isFile) {
                result.error("INVALID_IMAGE", "사진 파일을 읽을 수 없습니다", null)
                return@setMethodCallHandler
            }

            try {
                val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                val options = ImageLabelerOptions.Builder()
                    .setConfidenceThreshold(0.55f)
                    .build()
                val labeler = ImageLabeling.getClient(options)
                labeler.process(image)
                    .addOnSuccessListener { labels ->
                        val dogLabel = labels
                            .filter { it.index == 0 || it.text.equals("dog", ignoreCase = true) }
                            .maxByOrNull { it.confidence }
                        result.success(
                            mapOf(
                                "isDog" to (dogLabel != null),
                                "confidence" to (dogLabel?.confidence ?: 0f),
                                "labels" to labels.map { it.text }
                            )
                        )
                    }
                    .addOnFailureListener {
                        result.error("VALIDATION_FAILED", "사진을 판별할 수 없습니다", null)
                    }
                    .addOnCompleteListener { labeler.close() }
            } catch (_: Exception) {
                result.error("INVALID_IMAGE", "사진 파일을 읽을 수 없습니다", null)
            }
        }
    }
}
