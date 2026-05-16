# payanam

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 🔑 Secure Setup (API Keys)
This project has been scrubbed of sensitive API keys for security. To run it locally:

1.  **Dart Config**: Copy `lib/config/api_keys.dart.example` to `lib/config/api_keys.dart` and fill in your keys.
2.  **Android**: 
    -   Place your `google-services.json` in `android/app/`.
    -   Update `android/app/src/main/AndroidManifest.xml` with your Google Maps API key.
3.  **iOS**: 
    -   Place your `GoogleService-Info.plist` in `ios/Runner/`.
    -   Update `ios/Runner/AppDelegate.swift` with your Google Maps API key.
4.  **Web**: Update `web/index.html` with your Firebase config if needed.
