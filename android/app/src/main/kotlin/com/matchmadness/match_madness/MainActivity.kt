package com.matchmadness.match_madness

import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.matchmadness.match_madness/file"

    private var _permissionCallback: ((Boolean) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestStoragePermission" -> {
                    requestStoragePermission { granted ->
                        result.success(granted)
                    }
                }
                "writeToSharedStorage" -> {
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    if (fileName == null || content == null) {
                        result.error("INVALID_ARGS", "fileName and content required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        writeToSharedStorage(fileName, content)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WRITE_FAILED", e.message, null)
                    }
                }
                "readFromSharedStorage" -> {
                    val fileName = call.argument<String>("fileName")
                    if (fileName == null) {
                        result.error("INVALID_ARGS", "fileName required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val content = readFromSharedStorage(fileName)
                        result.success(content)
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            _permissionCallback?.invoke(granted)
            _permissionCallback = null
        }
    }

    private fun requestStoragePermission(callback: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ 需要请求所有文件权限才能让国产 ROM 弹出"文档和文件"对话框
            val permissions = arrayOf(
                android.Manifest.permission.READ_MEDIA_IMAGES,
                android.Manifest.permission.READ_MEDIA_VIDEO,
                android.Manifest.permission.READ_MEDIA_AUDIO
            )
            var allGranted = true
            for (p in permissions) {
                if (ContextCompat.checkSelfPermission(this, p) != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false
                    break
                }
            }
            if (allGranted) {
                callback(true)
                return
            }
            _permissionCallback = callback
            ActivityCompat.requestPermissions(this, permissions, 1001)
        } else {
            val permission = android.Manifest.permission.READ_EXTERNAL_STORAGE
            if (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED) {
                callback(true)
                return
            }
            _permissionCallback = callback
            ActivityCompat.requestPermissions(this, arrayOf(permission), 1001)
        }
    }

    private fun writeToSharedStorage(fileName: String, content: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ : use MediaStore
            deleteExistingFile(fileName)

            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                put(MediaStore.Downloads.RELATIVE_PATH, "wordbank")
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            uri?.let {
                contentResolver.openOutputStream(it)?.use { os ->
                    os.write(content.toByteArray(Charsets.UTF_8))
                    os.flush()
                }
            } ?: run {
                writeDirect(fileName, content)
            }
        } else {
            writeDirect(fileName, content)
        }
    }

    private fun writeDirect(fileName: String, content: String) {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "wordbank"
        )
        dir.mkdirs()
        File(dir, fileName).writeText(content, Charsets.UTF_8)
    }

    private fun deleteExistingFile(fileName: String) {
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
        val selectionArgs = arrayOf(fileName)
        contentResolver.delete(collection, selection, selectionArgs)
    }

    private fun readFromSharedStorage(fileName: String): String? {
        var result: String? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ : query MediaStore
            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val projection = arrayOf(MediaStore.Downloads._ID)
            val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
            val selectionArgs = arrayOf(fileName)

            contentResolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID))
                    val uri = Uri.withAppendedPath(collection, id.toString())
                    result = contentResolver.openInputStream(uri)?.use { it.reader().readText() }
                }
            }
        }

        // MediaStore 没找到时尝试直接文件访问（兼容国产 ROM）
        if (result == null) {
            val file = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "wordbank/$fileName"
            )
            if (file.exists()) {
                result = file.readText(Charsets.UTF_8)
            }
        }
        return result
    }
}