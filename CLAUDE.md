# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vika is a Flutter fitness app with AI-powered real-time pose detection. It uses Google ML Kit for pose estimation and selfie segmentation to analyze exercise form and provide coaching feedback. All user-facing strings are in Vietnamese.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter test             # Run tests
flutter analyze          # Run Dart analyzer/linter
flutter clean            # Clear build cache (fixes most build issues)
```

## Architecture

### Data Flow Pipeline (per frame)

Camera → ML Kit Pose Detection → One Euro Filter smoothing → Person detection (selfie segmentation) → Exercise state machine → Per-metric analysis → UI feedback

### Exercise System

**ExerciseBase** (`lib/exercise/exercise_base.dart`) is the abstract base class for all exercises. It manages a three-state machine: `notActivated` → `activated` → `completed`.

- **Activation**: User must hold still in the correct starting position for 3 seconds
- **Active tracking**: Each exercise composes multiple **Metric** objects that independently analyze form aspects (depth, alignment, tempo, etc.)
- **Completion**: Triggered when target rep count is reached

Each exercise lives in `lib/exercise/<name>/` with a `metrics/` subdirectory containing its metric classes. New exercises are registered in `ExerciseDefinition` (`lib/models/exercise_definition.dart`) which provides metadata and a factory function.

### Key Utilities (`lib/utils/`)

- **PoseSmoother**: One Euro Filter for low-latency landmark smoothing
- **PersonDetector**: ML Kit selfie segmentation at ~7Hz; dual-threshold (0.92 strict, 0.35 coverage) with 650ms presence confirmation
- **FrameBuffer**: Stores per-frame snapshots during a rep for peak detection and angle tracking
- **ExerciseLogger**: Aggregates per-rep data into set-level summaries
- **StickyDebouncer/Debouncer**: Hysteresis for state transitions (orientation detection uses 5-frame hysteresis)

### Interpreter Layer

`lib/interpreter/` analyzes logged exercise data post-set to detect form issues and generate coaching recommendations. Currently implemented for squats (`SquatInterpreter`).

### Screens

- **HomeScreen** (`lib/screens/home_screen.dart`): Exercise selection grid
- **Onboarding** (`lib/screens/onboarding/`): Multi-step flow including fitness assessment (5-rep squat/wall pushup), results interpreted via SquatInterpreter. Completion stored in SharedPreferences.

### Key Patterns

- **No external state management** — uses StatefulWidgets with local state and direct object mutation
- **ResultIssues.feedback** is cleared every frame (current-frame only); **ResultIssues.instructions** is keyed by phase and persists across frames
- **Camera facing auto-detection** via shoulder-width/torso-height ratio (FRONT: >0.57, SIDE: <0.35)
- **Scale factor** from shoulder-to-hip distance normalizes metrics across body sizes
- **Single `frameTimestamp`** set once per frame to avoid timing inconsistencies

## Conventions

- Constants: `UPPER_SNAKE_CASE` (analyzer ignores `constant_identifier_names`)
- Classes: `PascalCase`, variables/methods: `camelCase`
- Exercise directories may use spaces in names (e.g., `glute bridge/`)
- Uses `flutter_lints` for analysis rules

## Dependencies

- `camera` — camera access
- `google_mlkit_pose_detection` — pose landmark detection
- `google_mlkit_selfie_segmentation` — person presence detection
- `permission_handler` — runtime permissions
- `shared_preferences` — local persistence (onboarding state)
