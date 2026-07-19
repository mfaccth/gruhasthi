package com.gruhasthi.gruhasthi

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.SearchByTextRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val gemmaModelPickerRequestCode = 5104
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
