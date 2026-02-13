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
| AI Model           | YOLOv8-Nano (Quantized)             |
| Inference Engine   | LiteRT (formerly TFLite)            |
| Architecture       | Clean Architecture (Data, Domain, Presentation) |

## 📊 MSRI System

**Mangrove Structural Resilience Index (MSRI)**

A YOLOv8-Nano Classification Framework for Coastal Protection

### 1. Dataset Architecture

To train the YOLOv8-Nano model, the dataset must be organized into five distinct classification categories based on botanical biomechanics.

| Class Folder Name | Visual Indicators | Scientific Significance |
|-------------------|--------------------|--------------------------|
| Structural_Anchor_High | Dense, interlocking prop roots or thick pneumatophore matrices. | **Maximum Anchoring**: High root density increases shear strength and sediment binding. |
| Structural_Anchor_Low | Sparse, thin, or singular root systems; mostly visible mud. | **Vulnerability**: Minimum stability required to stand; zero redundancy against surge. |
| Erosional_Stress | Scoured mud, hollows under the trunk, roots hanging in the air. | **Foundation Failure**: Loss of substrate grip; the "lever arm" of the tree is compromised. |
| Mechanical_Damage | Snapped trunks, fractures, or leaning angles $>30^\circ$. | **Critical Failure**: Irreversible loss of wood integrity and load-bearing capacity. |
| Canopy_Necrosis | Yellowing, brown, or falling leaves (defoliation). | **Biological Vigor**: Indicator of recovery potential and root-cell health. |

### 2. The Biomechanical Scoring Engine

The system uses a Weighted Additive Model with a Biological Multiplier. The weights are assigned based on the hierarchy of structural importance.

**The Formula**

$$RI = \left[ (P_{HA} \times 100) + (P_{LA} \times 60) - (P_{ES} \times 50) - (P_{MD} \times 90) \right] \times (1.0 - P_{CN})$$

Where:

- $P$ = Probability (0.0 - 1.0) provided by YOLOv8-Nano.
- **100** (High Anchor): The "Gold Standard" of resilience.
- **60** (Low Anchor): The baseline for survival.
- **-50** (Erosion): A penalty for a failing foundation.
- **-90** (Damage): A heavy penalty for a broken pillar (trunk).
- **Multiplier** (1.0 - Necrosis): Voids the score if the tree is dead/dying (dead wood rots).

### 3. The "Safe Zone" Threshold

Based on structural engineering principles, we define the Safety Threshold for storm resilience:

| Threshold | Classification | Description |
|-----------|----------------|-------------|
| $\ge 75\%$ | **Safe** | The "Best Result." High root density provides enough "clout" and redundancy to survive Category 4+ wind/waves. |
| 50% - 74% | **Vulnerable** | Standing, but unlikely to withstand high storm surge. |
| < 50% | **Critical** | Immediate risk of failure; requires intervention. |

### 4. Flutter Implementation (Inference Logic)

The following logic processes the AI results using a Map to manage probabilities and `.clamp()` to ensure UI stability.

```dart
// Logic for calculating Resilience Index
double calculateResilience(Map<String, double> results) {
  // Extract probabilities from YOLO Map
  double pHA = results['Structural_Anchor_High'] ?? 0.0;
  double pLA = results['Structural_Anchor_Low'] ?? 0.0;
  double pES = results['Erosional_Stress'] ?? 0.0;
  double pMD = results['Mechanical_Damage'] ?? 0.0;
  double pCN = results['Canopy_Necrosis'] ?? 0.0;

  // 1. Calculate base structural score
  double structuralScore = (pHA * 100) + (pLA * 60) - (pES * 50) - (pMD * 90);

  // 2. Apply Biological Multiplier (Vigor)
  double finalScore = structuralScore * (1.0 - pCN);

  // 3. Use .clamp to keep score between 0 and 100
  return finalScore.clamp(0.0, 100.0);
}
```

### 5. Field Data Collection Protocol

To ensure the "Best Result" in classification accuracy, follow these rules:

- **Low Tide Only**: Photos for Erosional_Stress and Root_Density are invalid if submerged. The "Mud-to-Root" relationship must be visible.
- **Angle of Attack**: Eye-level (1.5m), 2–4 meters distance.
- **The "Trunk-Root" Junction**: Ensure the photo captures where the trunk meets the roots; this is the primary point of mechanical failure.
- **No High Tide Photos**: High tide creates reflections and hides foundation scours, leading to false "Safe" readings.

### 6. Visualization Strategy

The app should not just show a number; it must explain the Reality of the data:

- **Resilience Gauge**: A color-coded progress bar (Red/Yellow/Green).
- **Feature Breakdown**: A bar chart showing which penalty (Erosion vs Damage) lowered the score.
- **Safety Verdict**: A text summary (e.g., "High Root Density detected; the tree is an Elite Protector").

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

