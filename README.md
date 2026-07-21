# Gruhasthi

**Automate away your daily grind.**

Gruhasthi is a voice-first Android household assistant for a single user. It
keeps household data locally on the phone and is initially designed around
grocery ordering and simple payment handoffs.

## Features

- Press-and-hold English voice input for household requests.
- Separate grocery lists for each store, with quantities in count, dozen, kg,
  and litre.
- Add items, open lists, and send a prepared order to a store through the
  WhatsApp app.
- User-confirmed WhatsApp handoff: after WhatsApp is opened, the user can keep
  the list or mark it sent and clear it.
- Store management, including local Google Maps/Places discovery and WhatsApp
  numbers.
- Contact management and voice-assisted contact entry.
- Payment draft handoff to a supported UPI app; Gruhasthi never completes a
  payment itself.
- Optional on-device Gemma assistant for more flexible command wording. It is
  private to the phone and never bypasses the user review step.
- Local persistence for stores, grocery lists, contacts, and settings.

## Voice commands

Press and hold the microphone while speaking, then release to submit the
request. Commands are currently in English. Store names must match a store
saved in the app; `BigBasket` and `Big Basket` are treated as the same name.

The built-in parser accepts the following patterns. The optional on-device
Gemma assistant can interpret some more flexible wording, but every action is
still reviewed before it changes data, opens WhatsApp, or starts a payment
handoff.

| Task | Example phrases |
|---|---|
| Open Contacts | “Show me contacts.”<br>“Go to contacts list.” |
| Add a contact | “Add contact Vasu, phone number is 99801 01541.”<br>“Add contact Manohar 98455 98745.” |
| Open Stores | “Open stores.” |
| Add a store | “Add store Daily Fresh.”<br>“Add store Star Bazaar WhatsApp number 99801 99891.” |
| Update a store WhatsApp number | “Update the WhatsApp number for Big Basket to 99801 01541.”<br>“Set Village WhatsApp number to 99801 01541.” |
| Open grocery lists | “Open grocery lists.”<br>“Open Village list.” |
| Add a grocery item | “Add half litre milk to Village list.”<br>“Please add 2 kilograms rice to Big Basket.”<br>“Add one dozen eggs to Village.” |
| Send a prepared order | “Send Village list on WhatsApp.”<br>“Submit Big Basket list.” |

Supported quantity terms include counts, `dozen`, `kg`, `kilo`, `kilogram`,
`litre`/`liter`, `half`, and phrases such as “one and a half kg.”

## How was the App built
The App was build using Codex App. 

We use the GPT-5.6-Terra model at Medium Level for over 95% of the code generated. We leaned on GPT-5.6-Luna briefly, when GPT-5.6-Terra wasn't available due to availability constraints and we wanted to keep going.

We used Codex and the models to flesh out the Spec and create a detailed design before we began the implementation, to guide the implementation. As implementation progressed, we had to make some changes.

Codex was used to update the documents to reflect the final implementation


## Prerequisites

The primary build target is Android. The following steps assume macOS, but the
Flutter and Android commands are the same on other supported development
systems.

### Required software

1. **Flutter SDK** — use the stable channel compatible with the project’s Dart
   constraint (`^3.12.2`). Verify with `flutter --version`.
2. **Android Studio** — install the Android SDK, Android SDK Platform-Tools,
   and an Android platform accepted by Flutter.
3. **JDK 17** — required by the Android Gradle configuration.
4. A physical Android phone with **Developer options** and **USB debugging**
   enabled, or an Android emulator.

After installing Android Studio, run:

```bash
flutter doctor -v
flutter doctor --android-licenses
```

Resolve any Android toolchain issues reported by `flutter doctor` before
building.

### Optional services

#### Google Maps store discovery

Live store search uses the Google Places SDK for Android. Create an
Android-restricted API key in Google Cloud, enable **Places API (New)**, enable
billing, and add the following to `android/local.properties`:

```properties
PLACES_API_KEY=your_android_restricted_key
```

Restrict the key to application ID `com.gruhasthi.gruhasthi` and the SHA-1
certificate fingerprints used to sign the app. Do not commit `local.properties`
or share the API key. The app remains usable without it; only live store search
is unavailable.

#### On-device Gemma pilot

Gemma is optional and is not packaged in the APK. In the app, open
**Settings → On-device Gemma (pilot)** and use **Download & install** over
Wi-Fi. The app downloads, validates, and activates the selected model.

- **Gemma 4 E2B (recommended):** 2.59 GB download; allow about 6 GB free
  storage and use a phone with at least 6 GB RAM.
- **Gemma 4 E4B:** 3.66 GB download (3.41 GiB); allow about 10 GB free storage.
  An 8 GB RAM phone is recommended; 12 GB RAM provides smoother use.

Gemma interprets only constrained local commands. Gruhasthi validates the
result and still asks the user to review the proposed action.

## Build from source

Clone the repository and run all commands from its root.

```bash
git clone <repository-url> Gruhasthi
cd Gruhasthi
flutter pub get
flutter analyze
flutter test
```

Connect a phone, confirm that Flutter can see it, and run the debug build:

```bash
flutter devices
flutter run
```

If more than one device is shown, select one explicitly:

```bash
flutter run -d <device-id>
```

### Build a shareable release APK

For a properly signed release APK, create `android/key.properties`. This file
is intentionally ignored by Git.

Generate a new private keystore once with JDK 17's `keytool` (choose and retain
your own strong passwords):

```bash
keytool -genkeypair -v \
  -keystore ~/gruhasthi-release-key.jks \
  -alias gruhasthi \
  -keyalg RSA -keysize 2048 -validity 10000
```

`keytool` prompts for the keystore password, key password, and certificate
identity details. Keep the resulting `.jks` file and both passwords in a secure
password manager: the same signing key is needed for future updates to an app
already installed by users.

```properties
storePassword=<password chosen for the keystore>
keyPassword=<password chosen for the gruhasthi key>
keyAlias=gruhasthi
storeFile=/absolute/path/to/gruhasthi-release-key.jks
```

`storePassword` unlocks the keystore file; `keyPassword` unlocks the specific
key entry. They may be the same, but do not need to be. Do not commit or share
`key.properties`, the `.jks` file, or either password.

Build the APK:

```bash
flutter build apk --release
```

The output is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install it on a USB-connected phone:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Users can share this APK directly outside the Play Store. Android recipients
must allow installation from the chosen source (for example, Files, Drive, or
WhatsApp) and will see the standard unknown-app installation prompt.

## Useful checks

```bash
flutter analyze
flutter test
flutter build apk --release
```

See [voice transcript capture design](docs/voice-transcript-capture-design.md)
for the speech-capture lifecycle and transcript de-duplication approach.
