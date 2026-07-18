package com.gruhasthi.gruhasthi

import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.SearchByTextRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
