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

On an Android phone, open **Settings → On-device Gemma (pilot)** and choose a
model:

- **Gemma 4 E2B (recommended):** smaller and faster for most phones. Download
  `gemma-4-E2B-it.litertlm`; leave about 6 GB of free storage while installing.
- **Gemma 4 E4B (higher capability, pilot):** a 3.66 GB model for capable
  phones. Download `gemma-4-E4B-it.litertlm`; leave about 10 GB of free storage
  when replacing a model.

Use **Download selected**, then return to Gruhasthi and choose the downloaded
file through Android's document picker. Gruhasthi verifies the exact filename,
copies it into its private model location, and replaces any previously active
model. The user does not need to access `Android/data` or run ADB commands.

In a voice review sheet, select **Interpret with
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
