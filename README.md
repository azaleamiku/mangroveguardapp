# MangroveGuard

An Optimized Computer Vision Tool for Mangrove Stability Assessment

MangroveGuard is a mobile application designed to automate the assessment of mangrove tree health and coastal stability. By leveraging YOLOv10-Nano for real-time root quantification, it provides a high-accessibility tool for researchers and coastal communities—even on mid-range hardware.

## Key Features

- **Real-time Root Quantification**: Uses an optimized YOLOv10-Nano model (Quantized) for near-instant detection of aerial roots.
- **Stability Indexing**: Generates a quantitative "Stability Score" based on root density and trunk structural integrity.
- **Offline-First Research**: All AI inference happens on-device via LiteRT, enabling use in remote mangrove forests without internet.
- **Educational Onboarding**: Built-in information modules on mangrove conservation and data privacy.

## Tech Stack

| Component          | Technology                          |
|--------------------|-------------------------------------|
| Framework          | Flutter (Dart)                     |
| AI Model           | YOLOv8-Nano (Quantized)             |
| Inference Engine   | LiteRT (formerly TFLite)            |
| Architecture       | Clean Architecture (Data, Domain, Presentation) |

## Calculation Framework

### 1. AI Class Definitions

The model is trained on four mask classes:

| Class ID | Name | Role |
|---|---|---|
| 0 | `mangrove_tree` | Parent mask: defines the Area of Interest (AOI) |
| 1 | `prop_root` | Child mask: structural anchoring calculations |
| 2 | `leaf_healthy` | Child mask: baseline biological health |
| 3 | `necrosis` | Child mask: disease/stress indicator |

### 2. Mathematical Ledger

#### Phase A: Structural Integrity (Root Scan)

Objective: Calculate Root Area Ratio (RAR) and Stability with tidal correction.

1. Anchor Zone (`P_anchor`), lower 30% of `mangrove_tree`:

$$P_{anchor} = \sum \text{pixels} \in [y_{base}, y_{base} - 0.3H_{tree}]$$

2. Tidal Correction Factor (`γ`):
- Low Tide: `γ = 1.0`
- Mid Tide: `γ = 1.4`
- High Tide: `γ = INVALID` (scan blocked)

3. Root Density:

$$D_r = \left( \frac{P_{root}}{P_{anchor}} \right) \times \gamma$$

4. Normalized Stability:

$$S = \min\left(100, \left( \frac{D_r}{0.60} \right) \times 100\right)$$

#### Phase B: Biological Health (Optional Canopy Scan)

Objective: Calculate Necrosis Index (NI) and Health. If canopy is inaccessible (e.g., tall trees), this phase is skipped.

1. Necrosis Index:

$$NI = \frac{\sum \text{pixels}_{Class\ 3}}{\sum \text{pixels}_{Class\ 2} + \sum \text{pixels}_{Class\ 3}}$$

2. Normalized Health:

$$H = (1 - NI) \times 100$$

#### Phase C: Final Score (Dynamic Resilience Index)

The system switches modes based on data availability:

| Mode | Trigger | Formula | Confidence |
|---|---|---|---|
| Comprehensive | Root + Canopy scans | `RI = (S × 0.70) + (H × 0.30)` | High (100%) |
| Structural Only | Root scan only | `RI = S × 1.0` | Medium (70%) |

### 3. Data Visualization Strategy

- **Resilience Gauge**: Radial gauge for `RI` (0–100) with confidence badge (`High`/`Medium`) depending on canopy scan availability.
- **Comparison Radar Chart**:
  - Full data: `Stability` vs `Health`
  - Partial data: `Stability` vs `Historical Average`
- **Longitudinal Trend Lines**: Track `S`, `H`, and `RI` over time; structural-only data points are dashed.
- **Dynamic Necrosis View**: Displays necrosis trend over time with a current severity state (`Low`, `Moderate`, `Severe`) for faster canopy stress interpretation.

### 4. Flutter Implementation Architecture

#### Required Plugins

- `ultralytics_yolo` (AI inference)
- `geolocator` + `http` (tide data integration)
- `fl_chart` (data visualizations)

#### Dynamic Workflow Logic

```dart
double calculateFinalRI(double stability, double? health) {
  if (health == null) {
    // Mode: Structural Only (for tall trees or skipped canopy scans)
    return stability;
  } else {
    // Mode: Comprehensive
    return (stability * 0.7) + (health * 0.3);
  }
}
```

#### System State Logic

1. Pre-flight: tidal validation via GPS/API.
2. Identification: detect `mangrove_tree`.
3. Primary scan: analyze roots and compute `S`.
4. User choice: `Scan Canopy? (Skip for tall trees)`.
5. Secondary scan (optional): analyze leaves and compute `H`.
6. Result: compute `RI` using dynamic weighting and display confidence rating.

### 5. Field Data Constraints

- Height workaround: if tree height is `>3m`, use Structural Only mode for safety/accuracy.
- Tidal timing: best results ±2 hours from lowest tide.
- Image scaling: maintain ~1.5m distance for root scans.

## Project Structure

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

## Getting Started

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

## Data Privacy & Terms

MangroveGuard is designed for ecological research. By using this tool:

- You agree to the local regulations regarding coastal data collection.
- Location data is used only for tagging tree assessments and is not shared with third parties.
- All image processing is done locally on your device; no images are uploaded to external servers.

## Proponents

- **Ivan Kly B. Lamason** | Lead Systems Architect & Project Coordinator

- **Dan Coby G. Tabao** | Lead Systems Developer & Data Engineer

- **Elzen Rein Marco Maceda** | UI/UX Designer & ML Specialist

- **Vincent N. Pensader** | Solutions Engineer & Technical Writer

## Co-Author / Adviser

- **Devine Grace Funcion, MSIT** - Bachelor of Science in Information Technology

**Institution**: Leyte Normal University - College of Arts and Sciences | Bachelor of Science in Information Technology

## License

This project is licensed under the MIT License - see the LICENSE file for details.
