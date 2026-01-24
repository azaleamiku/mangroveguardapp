# 🌿 MangroveGuard

An Optimized Computer Vision & Spatial Computing Tool for Mangrove Stability Assessment

MangroveGuard is a mobile application designed to automate the assessment of mangrove tree health and coastal stability. By leveraging YOLOv10-Nano for real-time root quantification and ARCore Raw Depth API for precise trunk measurement, it provides a high-accessibility tool for researchers and coastal communities—even on mid-range hardware like the TECNO Camon 30.

## 🚀 Key Features

- **Real-time Root Quantification**: Uses an optimized YOLOv10-Nano model (Quantized) for near-instant detection of aerial roots.
- **AR-Based DBH Measurement**: Calculates Diameter at Breast Height (DBH) using motion-based depth mapping to estimate tree age without specialized LiDAR sensors.
- **Stability Indexing**: Generates a quantitative "Stability Score" based on root density and trunk structural integrity.
- **Offline-First Research**: All AI inference and AR processing happen on-device via LiteRT, enabling use in remote mangrove forests without internet.
- **Educational Onboarding**: Built-in information modules on mangrove conservation and data privacy.

## 🛠️ Tech Stack

| Component          | Technology                          |
|--------------------|-------------------------------------|
| Framework          | Flutter (Dart)                      |
| Rendering          | Impeller Engine (Low-latency AR Overlays) |
| AI Model           | YOLOv10-Nano (INT8 Quantized)       |
| Inference Engine   | LiteRT (formerly TFLite)            |
| AR Core            | Google ARCore (Raw Depth API)       |
| Architecture       | Clean Architecture (Data, Domain, Presentation) |

## 🏗️ Project Structure

The project follows Clean Architecture to maintain high performance during simultaneous AI and AR tasks:

```
lib/
├── core/               # App-wide themes, constants, and utilities
├── features/
│   ├── home/           # Dashboard and research statistics
│   ├── scanner/        # ARCore + YOLOv10 implementation
│   ├── onboarding/     # Privacy, Terms, and Educational info
│   └── navigation/     # Persistent Bottom Nav Bar logic
└── main.dart           # Application entry point
```

## 📱 Getting Started

### Prerequisites

- Flutter SDK (v3.27 or higher)
- Android Studio / VS Code
- An ARCore-supported device (e.g., TECNO Camon 30, Samsung S-Series, etc.)

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

## 🔧 How it Works

### DBH Calculation Using AR Coordinates

The Diameter at Breast Height (DBH) is calculated using the ARCore Raw Depth API to obtain precise depth information around the trunk, enabling estimation of tree age without specialized equipment.

1. **Point Cloud Acquisition**: The app captures a point cloud of the trunk at breast height (approximately 1.3 meters from the ground) using ARCore's depth sensor.

2. **Depth Mapping**: Depth data is processed to identify surface points of the trunk, filtering out background noise.

3. **Circle Fitting**: The identified points are fitted to a circle using a least squares optimization method to estimate the trunk's diameter.

   The DBH is calculated as:
   
   **DBH = 2 × r**
   
   Where:
   - **r** is the radius obtained from the circle fit
   - The circle fit minimizes the sum of squared distances from points to the circle circumference

4. **Motion-Based Refinement**: By combining depth maps from multiple frames during user movement, the estimation is refined for higher accuracy, accounting for occlusions and sensor noise.

This approach leverages spatial computing to provide reliable measurements comparable to traditional caliper methods, adapted for mobile AR environments.

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
