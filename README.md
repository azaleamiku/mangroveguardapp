<p align="center">
  <img src="images/MangroveGuardLogo.png" alt="Mangrove Guard Logo" width="110" />
</p>

<h1 align="center">Mangrove Guard App</h1>

<p align="center">
  AI-assisted mangrove scanning with on-device ML inference, local scan intelligence, and field-ready PDF exports.
</p>

<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=500&size=18&pause=1400&color=0B8A83&center=true&vCenter=true&width=960&lines=Camera-guided+scan+workflow;TensorFlow+Lite+inference+running+on-device;Live+stability+metrics+with+history+tracking;One-tap+PDF+report+export" alt="Animated intro" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Mobile_App-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.10.7-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/TensorFlow_Lite-On_Device_Inference-FF6F00?logo=tensorflow&logoColor=white" alt="TFLite" />
  <img src="https://img.shields.io/badge/Local_Storage-SharedPreferences-4CAF50" alt="SharedPreferences" />
  <img src="https://img.shields.io/badge/PDF-Report_Export-B30B00" alt="PDF" />
</p>

## What It Does

- Captures mangrove scans using a guided camera frame.
- Runs TensorFlow Lite inference directly on-device.
- Calculates stability from root spread vs trunk width ratio.
- Tracks metrics and recent scans using local persistence.
- Exports detailed PDF reports per scan.
- Shows onboarding once, then routes directly to home.

## Stability Logic

| Ratio (Root Spread / Trunk Width) | Classification |
| --- | --- |
| `> 3.0` | `High` |
| `>= 1.5` and `<= 3.0` | `Moderate` |
| `< 1.5` | `Low` |

## Tech Stack

- Flutter / Dart (`sdk: ^3.10.7`)
- `camera` for image capture
- `tflite_flutter` for on-device inference
- `shared_preferences` for persisted app state
- `path_provider` for local file paths
- `pdf` for report generation

## Project Structure

```text
lib/
  main.dart
  features/
    onboarding/presentation/pages/onboarding_page.dart
    navigation/presentation/
      main_nav_page.dart
      metrics_page.dart
      recent_scan_page.dart
    home/
      presentation/pages/scanner_page.dart
      models/mangrove_tree.dart
assets/
  models/mangroveModel.tflite
  fonts/
images/
```

## Quick Start

```bash
flutter pub get
flutter run
```

## Useful Commands

```bash
flutter analyze
flutter test
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## Platform Notes

- Android `minSdk` is `26`.
- Camera permission is configured for Android and iOS.
- Android uses native method channel `mangroveguardapp/downloads` to:
  - save exported PDFs to `Downloads/MangroveGuard`
  - open exported PDFs with chooser intent

## Data and Storage

- Onboarding completion flag: `showHome` (`SharedPreferences`)
- Recent scans key: `recent_tree_scans_v1` (`SharedPreferences`)
- Captured scan images directory: `scan_captures`
- Non-Android PDF fallback directory: `scan_exports`

## Implementation Notes

- Current measurement conversion uses fixed `metersPerPixel = 0.003` in scan pipeline.
- Model output handling supports both mask-style and instance-style tensors.
