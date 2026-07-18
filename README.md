# Gruhasthi

Voice-first household automation for a single user in Kundalahalli, Bengaluru.

## Google Maps store discovery

The Android build uses the native Google Places SDK for Android. To enable live
store discovery, create an Android-restricted API key in Google Cloud, enable
Places API (New), then add this line to `android/local.properties` on your own
machine (do not commit or share the key):

```properties
PLACES_API_KEY=your_android_restricted_key
```

Restrict the key to Android app package `com.gruhasthi.gruhasthi` and the
appropriate signing SHA-1 certificate. Google Cloud billing is required by
Google Places. Without a key, the app remains usable and the store finder
explains that it has not been configured.

## On-device Gemma pilot (Android)

The pilot uses the LiteRT-LM runtime and the optional Gemma 4 E2B model to
interpret a reviewed voice transcript locally. It does not replace the final
user confirmation, and the existing rule-based command parser remains the
fallback.

The model is not included in the APK. It is approximately 2.6 GB and must be
downloaded separately from the [LiteRT Community Gemma 4 E2B model
page](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm).

After installing the debug app on a connected Android phone, copy the
downloaded `gemma-4-E2B-it.litertlm` file to the phone with:

```bash
/Users/manohar/Library/Android/sdk/platform-tools/adb shell \
  mkdir -p /storage/emulated/0/Android/data/com.gruhasthi.gruhasthi/files/models

/Users/manohar/Library/Android/sdk/platform-tools/adb push \
  /path/to/gemma-4-E2B-it.litertlm \
  /storage/emulated/0/Android/data/com.gruhasthi.gruhasthi/files/models/gemma-4-E2B-it.litertlm
```

Open **Settings → On-device Gemma (pilot)** and use **Check again** to confirm
that the model is available. In a voice review sheet, select **Interpret with
on-device Gemma (pilot)**. The model returns only a constrained local command;
Gruhasthi validates it and still shows the usual review action.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
