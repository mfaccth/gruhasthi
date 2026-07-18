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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
