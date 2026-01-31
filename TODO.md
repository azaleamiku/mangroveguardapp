# TODO: Make UI Futuristic, Nature-Themed, and Minimal

## Overview
Update the Flutter app's UI to be futuristic and nature-themed using the provided color scheme, while keeping it minimal. Incorporate greens for nature, modern design elements for futuristic feel, and clean layouts for minimalism.

## Color Scheme
- Caribbean Green (#00DF81): Primary Accent / Logo Icon
- Anti-Flash White (#F1F7F6): Backgrounds / Light Text
- Bangladesh Green (#03624C): Secondary Brand Color
- Dark Green (#032221): Deep UI Elements / Containers
- Rich Black (#021B1A): Main Background / Dark Text

## Tasks
- [x] Update ThemeData in main.dart to use new color scheme
- [x] Modify onboarding_page.dart for minimal, futuristic design with new colors
- [x] Update home_page.dart: Make stat cards futuristic and minimal
- [x] Adjust main_nav_page.dart: Update bottom navigation colors and style
- [x] Add CAMERA permission and ARCore metadata to AndroidManifest.xml
- [x] Update android/app/build.gradle.kts to set minSdk to 24 for ARCore
- [x] Implement AR-ready scanner_page.dart with futuristic UI
- [x] Implement DBH measurement functionality with measurement guide
- [ ] Integrate actual ARCore functionality (requires physical device testing)

## Followup Steps
- Test the app on a physical Android device with ARCore support
- Implement actual ARCore camera feed using ar_flutter_plugin
- Add YOLOv10-Nano model integration for mangrove health analysis
- Add data logging features with export capabilities
