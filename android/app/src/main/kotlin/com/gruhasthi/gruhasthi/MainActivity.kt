package com.gruhasthi.gruhasthi

import android.app.Activity
import android.app.DownloadManager
import android.content.Intent
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.OpenableColumns
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.SearchByTextRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val gemmaModelPickerRequestCode = 5104
        private const val gemmaDownloadIdKey = "model_download_id"
        private const val gemmaDownloadModelIdKey = "model_download_id_model"
        private const val gemmaDownloadPathKey = "model_download_path"
    }

    private val gemmaExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var gemmaCommandEngine: GemmaCommandEngine? = null
    private var pendingGemmaModelPick: MethodChannel.Result? = null
    private var pendingGemmaModelId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gruhasthi.gruhasthi/payment_apps")
            .setMethodCallHandler { call, result ->
                if (call.method != "openGooglePay") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val launchIntent = packageManager.getLaunchIntentForPackage(
                    "com.google.android.apps.nbu.paisa.user",
                )
                if (launchIntent == null) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(launchIntent)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gruhasthi.gruhasthi/store_search")
            .setMethodCallHandler { call, result ->
                if (call.method != "searchNearbyStores") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val apiKey = BuildConfig.PLACES_API_KEY
                if (apiKey.isBlank() || apiKey == "DEFAULT_API_KEY") {
                    result.error(
                        "API_KEY_MISSING",
                        "Google Places is not configured on this build.",
                        null,
                    )
                    return@setMethodCallHandler
                }

                val searchText = call.argument<String>("query")?.trim().orEmpty()
                if (searchText.isBlank()) {
                    result.error("INVALID_QUERY", "Enter what you want to find.", null)
                    return@setMethodCallHandler
                }
                val locality = call.argument<String>("locality")?.trim()
                    .takeUnless { it.isNullOrBlank() }
                    ?: "Kundalahalli, Bengaluru"

                try {
                    if (!Places.isInitialized()) {
                        Places.initializeWithNewPlacesApiEnabled(applicationContext, apiKey)
                    }
                    val request = SearchByTextRequest.builder(
                        "$searchText in $locality",
                        listOf(Place.Field.DISPLAY_NAME, Place.Field.FORMATTED_ADDRESS),
                    ).setMaxResultCount(10).build()

                    Places.createClient(this).searchByText(request)
                        .addOnSuccessListener { response ->
                            result.success(
                                response.places.map { place ->
                                    mapOf(
                                        "name" to (place.displayName ?: "Unnamed store"),
                                        "address" to (place.formattedAddress ?: locality),
                                    )
                                },
                            )
                        }
                        .addOnFailureListener { exception ->
                            result.error(
                                "SEARCH_FAILED",
                                exception.message ?: "Google Maps could not complete the search.",
                                null,
                            )
                        }
                } catch (exception: Exception) {
                    result.error(
                        "SEARCH_FAILED",
                        exception.message ?: "Google Maps could not start the search.",
                        null,
                    )
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gruhasthi.gruhasthi/gemma")
            .setMethodCallHandler { call, result ->
                val interpreter = gemmaCommandEngine
                    ?: GemmaCommandEngine(applicationContext).also { gemmaCommandEngine = it }
                when (call.method) {
                    "status" -> result.success(interpreter.status())
                    "pickAndInstallModel" -> {
                        val modelId = call.argument<String>("modelId") ?: GemmaCommandEngine.defaultModelId
                        openGemmaModelPicker(modelId, result)
                    }
                    "startModelDownload" -> {
                        val modelId = call.argument<String>("modelId") ?: GemmaCommandEngine.defaultModelId
                        startGemmaModelDownload(modelId, result)
                    }
                    "modelDownloadStatus" -> result.success(gemmaDownloadStatus())
                    "installDownloadedModel" -> {
                        val modelId = call.argument<String>("modelId") ?: GemmaCommandEngine.defaultModelId
                        installDownloadedGemmaModel(modelId, result)
                    }
                    "cancelModelDownload" -> {
                        cancelGemmaModelDownload()
                        result.success(null)
                    }
                    "interpretTranscript" -> {
                        val transcript = call.argument<String>("transcript")?.trim().orEmpty()
                        val stores = call.argument<List<String>>("stores") ?: emptyList()
                        if (transcript.isBlank()) {
                            result.error("INVALID_TRANSCRIPT", "Say or type a command first.", null)
                            return@setMethodCallHandler
                        }
                        gemmaExecutor.execute {
                            try {
                                val response = interpreter.interpret(transcript, stores)
                                runOnUiThread { result.success(response) }
                            } catch (exception: ModelUnavailableException) {
                                runOnUiThread {
                                    result.error("MODEL_UNAVAILABLE", exception.message, interpreter.status())
                                }
                            } catch (exception: Exception) {
                                runOnUiThread {
                                    result.error(
                                        "INTERPRETATION_FAILED",
                                        exception.message ?: "Gemma could not understand that command.",
                                        null,
                                    )
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startGemmaModelDownload(modelId: String, result: MethodChannel.Result) {
        val spec = GemmaCommandEngine.modelSpec(modelId)
        if (spec == null) {
            result.error("UNSUPPORTED_MODEL", "Choose a supported Gemma model.", null)
            return
        }
        val existing = gemmaDownloadStatus()
        if (existing["modelId"] == modelId && existing["state"] in setOf("pending", "downloading")) {
            result.success(existing)
            return
        }
        cancelGemmaModelDownload()

        val downloadDirectory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: File(filesDir, "downloads")
        downloadDirectory.mkdirs()
        val availableBytes = StatFs(downloadDirectory.absolutePath).availableBytes
        if (availableBytes < spec.requiredFreeBytes) {
            result.error(
                "INSUFFICIENT_STORAGE",
                "Free up enough storage before downloading ${spec.displayName}.",
                mapOf("requiredBytes" to spec.requiredFreeBytes, "availableBytes" to availableBytes),
            )
            return
        }
        val target = File(downloadDirectory, "${spec.fileName}.download")
        target.delete()
        val request = DownloadManager.Request(Uri.parse(spec.downloadUrl))
            .setTitle("Downloading ${spec.displayName}")
            .setDescription("Gruhasthi will verify and install it automatically.")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(false)
            .setDestinationInExternalFilesDir(
                this,
                Environment.DIRECTORY_DOWNLOADS,
                target.name,
            )
        val downloadId = downloadManager().enqueue(request)
        downloadPreferences().edit()
            .putLong(gemmaDownloadIdKey, downloadId)
            .putString(gemmaDownloadModelIdKey, modelId)
            .putString(gemmaDownloadPathKey, target.absolutePath)
            .apply()
        result.success(gemmaDownloadStatus())
    }

    private fun installDownloadedGemmaModel(modelId: String, result: MethodChannel.Result) {
        val status = gemmaDownloadStatus()
        if (status["state"] != "downloaded" || status["modelId"] != modelId) {
            result.error("DOWNLOAD_NOT_READY", "The selected model has not finished downloading.", status)
            return
        }
        val path = downloadPreferences().getString(gemmaDownloadPathKey, null)
        if (path == null) {
            result.error("DOWNLOAD_NOT_FOUND", "The downloaded model could not be found.", null)
            return
        }
        val interpreter = gemmaCommandEngine
            ?: GemmaCommandEngine(applicationContext).also { gemmaCommandEngine = it }
        gemmaExecutor.execute {
            try {
                val installed = interpreter.installDownloadedModel(modelId, File(path))
                File(path).delete()
                clearGemmaDownload()
                runOnUiThread { result.success(installed) }
            } catch (exception: Exception) {
                runOnUiThread {
                    result.error(
                        "MODEL_INSTALL_FAILED",
                        exception.message ?: "Gruhasthi could not install the downloaded Gemma model.",
                        null,
                    )
                }
            }
        }
    }

    private fun gemmaDownloadStatus(): Map<String, Any> {
        val preferences = downloadPreferences()
        val downloadId = preferences.getLong(gemmaDownloadIdKey, -1L)
        val modelId = preferences.getString(gemmaDownloadModelIdKey, null)
        if (downloadId < 0L || modelId == null) return mapOf("state" to "none")
        val cursor = downloadManager().query(DownloadManager.Query().setFilterById(downloadId))
        cursor.use {
            if (!it.moveToFirst()) {
                clearGemmaDownload()
                return mapOf("state" to "none")
            }
            val status = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val bytes = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
            val total = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            val state = when (status) {
                DownloadManager.STATUS_PENDING, DownloadManager.STATUS_PAUSED -> "pending"
                DownloadManager.STATUS_RUNNING -> "downloading"
                DownloadManager.STATUS_SUCCESSFUL -> "downloaded"
                else -> "failed"
            }
            val response = mutableMapOf<String, Any>(
                "state" to state,
                "modelId" to modelId,
                "bytesDownloaded" to bytes,
                "totalBytes" to total,
            )
            if (status == DownloadManager.STATUS_FAILED) {
                response["message"] = "The model download failed. Check Wi-Fi and try again."
            }
            return response
        }
    }

    private fun cancelGemmaModelDownload() {
        val downloadId = downloadPreferences().getLong(gemmaDownloadIdKey, -1L)
        if (downloadId >= 0L) downloadManager().remove(downloadId)
        downloadPreferences().getString(gemmaDownloadPathKey, null)?.let { File(it).delete() }
        clearGemmaDownload()
    }

    private fun clearGemmaDownload() {
        downloadPreferences().edit()
            .remove(gemmaDownloadIdKey)
            .remove(gemmaDownloadModelIdKey)
            .remove(gemmaDownloadPathKey)
            .apply()
    }

    private fun downloadManager() = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    private fun downloadPreferences() = getSharedPreferences("gemma_download", Context.MODE_PRIVATE)

    private fun openGemmaModelPicker(modelId: String, result: MethodChannel.Result) {
        if (pendingGemmaModelPick != null) {
            result.error("PICKER_BUSY", "A model file is already being selected.", null)
            return
        }
        if (GemmaCommandEngine.expectedFileName(modelId) == null) {
            result.error("UNSUPPORTED_MODEL", "Choose a supported Gemma model.", null)
            return
        }
        pendingGemmaModelPick = result
        pendingGemmaModelId = modelId
        val pickerIntent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivityForResult(pickerIntent, gemmaModelPickerRequestCode)
    }

    @Deprecated("Deprecated in Android API 30")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != gemmaModelPickerRequestCode) return

        val result = pendingGemmaModelPick ?: return
        pendingGemmaModelPick = null
        val modelId = pendingGemmaModelId
        pendingGemmaModelId = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.error("MODEL_PICK_CANCELLED", "No Gemma model file was selected.", null)
            return
        }

        val sourceName = displayName(uri)
        val expectedFileName = modelId?.let { GemmaCommandEngine.expectedFileName(it) }
        if (expectedFileName == null || sourceName != expectedFileName) {
            result.error(
                "INVALID_MODEL_FILE",
                "Choose the ${expectedFileName ?: "selected"} model file.",
                null,
            )
            return
        }
        val interpreter = gemmaCommandEngine
            ?: GemmaCommandEngine(applicationContext).also { gemmaCommandEngine = it }
        gemmaExecutor.execute {
            try {
                val installed = contentResolver.openInputStream(uri)?.use { input ->
                    interpreter.installModel(modelId, sourceName, input)
                } ?: throw IllegalStateException("Gruhasthi could not read the selected model file.")
                runOnUiThread { result.success(installed) }
            } catch (exception: Exception) {
                runOnUiThread {
                    result.error(
                        "MODEL_INSTALL_FAILED",
                        exception.message ?: "Gruhasthi could not install the selected Gemma model.",
                        null,
                    )
                }
            }
        }
    }

    private fun displayName(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (column >= 0 && cursor.moveToFirst()) return cursor.getString(column)
            }
        return uri.lastPathSegment?.substringAfterLast('/')
    }

    override fun onDestroy() {
        gemmaExecutor.shutdownNow()
        gemmaCommandEngine?.close()
        super.onDestroy()
    }
}
