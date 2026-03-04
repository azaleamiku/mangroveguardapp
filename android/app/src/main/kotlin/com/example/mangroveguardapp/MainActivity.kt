package com.example.mangroveguardapp

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val downloadsChannel = "mangroveguardapp/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePdfToDownloads" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")
                        if (bytes == null || fileName.isNullOrBlank()) {
                            result.error("invalid_args", "Missing PDF bytes or filename", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(savePdfToDownloads(bytes, fileName))
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }

                    "openExportedPdf" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(openExportedPdf(path))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun savePdfToDownloads(bytes: ByteArray, fileName: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/MangroveGuard",
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val resolver = applicationContext.contentResolver
            val itemUri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("Unable to create MediaStore record.")

            resolver.openOutputStream(itemUri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IOException("Unable to open output stream for $itemUri")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)
            return itemUri.toString()
        }

        val downloadsDir =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val appDir = File(downloadsDir, "MangroveGuard")
        if (!appDir.exists()) {
            appDir.mkdirs()
        }
        val file = File(appDir, fileName)
        FileOutputStream(file).use { stream ->
            stream.write(bytes)
            stream.flush()
        }
        return file.absolutePath
    }

    private fun openExportedPdf(pathOrUri: String): Boolean {
        return try {
            val uri = if (pathOrUri.startsWith("content://") || pathOrUri.startsWith("file://")) {
                Uri.parse(pathOrUri)
            } else {
                val file = File(pathOrUri)
                FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file,
                )
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            val chooser = Intent.createChooser(intent, "Open exported PDF").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(chooser)
            true
        } catch (_: Exception) {
            false
        }
    }
}
