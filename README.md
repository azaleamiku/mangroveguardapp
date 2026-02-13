# 🌿 MangroveGuard

An Optimized Computer Vision Tool for Mangrove Stability Assessment

MangroveGuard is a mobile application designed to automate the assessment of mangrove tree health and coastal stability. By leveraging YOLOv10-Nano for real-time root quantification, it provides a high-accessibility tool for researchers and coastal communities—even on mid-range hardware.

## 🚀 Key Features

- **Real-time Root Quantification**: Uses an optimized YOLOv10-Nano model (Quantized) for near-instant detection of aerial roots.
- **Stability Indexing**: Generates a quantitative "Stability Score" based on root density and trunk structural integrity.
- **Offline-First Research**: All AI inference happens on-device via LiteRT, enabling use in remote mangrove forests without internet.
- **Educational Onboarding**: Built-in information modules on mangrove conservation and data privacy.

## 🛠️ Tech Stack

| Component          | Technology                          |
|--------------------|-------------------------------------|
| Framework          | Flutter (Dart)                     |
| AI Model           | YOLOv10-Nano (INT8 Quantized)       |
| Inference Engine   | LiteRT (formerly TFLite)            |
| Architecture       | Clean Architecture (Data, Domain, Presentation) |

## 🏗️ Project Structure

The project follows Clean Architecture to maintain high performance during AI tasks:

```
lib/
├── core/               # App-wide themes, constants, and utilities
├── features/
│   ├── home/           # Dashboard and research statistics
│   ├── scanner/        # YOLOv10 implementation
│   ├── onboarding/     # Privacy, Terms, and Educational info
│   └── navigation/     # Persistent Bottom Nav Bar logic
└── main.dart           # Application entry point
```

## 📱 Getting Started

### Prerequisites

- Flutter SDK (v3.27 or higher)
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/MangroveGuard.git
   cd MangroveGuard
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up AI Assets**  
   Place your `yolov10n_quantized.tflite` model and `labels.txt` in the `assets/` folder.

4. **Run the app**
   ```bash
   flutter run
   ```

## 🛡️ Data Privacy & Terms

MangroveGuard is designed for ecological research. By using this tool:

- You agree to the local regulations regarding coastal data collection.
- Location data is used only for tagging tree assessments and is not shared with third parties.
- All image processing is done locally on your device; no images are uploaded to external servers.

## 👥 Proponents

- **Ivan Kly B. Lamason** - Leader
- **Dan Coby G. Tabao** - Member
- **Elzen Rein Marco Maceda** - Member

**Institution**: Leyte Normal University - College of Arts and Sciences

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

