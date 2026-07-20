# Open items and technical debt

## High priority before wider distribution

### Signed remote Gemma model manifest

The current in-app Gemma downloader has the approved model URL, expected file
size, and SHA-256 checksum compiled into the Android app. This is safe for the
pilot, but changing a model file or checksum requires a new Gruhasthi release.

Replace the compiled manifest with a small remotely hosted manifest containing:

- model ID and version;
- download URL;
- expected file size and SHA-256 checksum;
- minimum supported app version; and
- release notes or compatibility guidance.

The manifest must be signed. Gruhasthi should embed the corresponding public
key, verify the signature before trusting any remote values, and keep the last
verified manifest available for offline use. The app must reject unsigned,
expired, malformed, or incompatible manifests.

This allows a verified model update without an APK release, while protecting
users from a substituted model download.

## Follow-up considerations

- Move model files to a Gruhasthi-controlled CDN after confirming redistribution
  obligations and attribution requirements.
- Add model-download telemetry that is opt-in and contains no voice transcript
  or personal data.
- Test interrupted-download recovery, low-storage handling, Wi-Fi loss, and
  checksum failures on representative Android phones.
- Reconsider a supported **manual model-file import** route for offline or
  enterprise deployment. It is intentionally hidden from the current
  non-technical-user flow to avoid confusing model selection and validation.
