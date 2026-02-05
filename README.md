# Vinafit Mobile

A Flutter fitness app with AI-powered pose detection for exercise tracking.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (>= 3.0.0) - [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Android Studio** or **VS Code** with Flutter extension
- **Android SDK** (for Android development)
- **Xcode** (for iOS development, macOS only)

## Quick Start (3 Steps)

### 1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/vinafit_mobile.git
cd vinafit_mobile
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Run the app
```bash
# Check connected devices
flutter devices

# Run on connected device/emulator
flutter run
```

## Platform-Specific Setup

### Android
- Minimum SDK: 21 (Android 5.0)
- Camera permission required

### iOS
- Minimum iOS: 12.0
- Add camera permission description in `ios/Runner/Info.plist`

## Common Commands

| Command | Description |
|---------|-------------|
| `flutter pub get` | Install dependencies |
| `flutter run` | Run in debug mode |
| `flutter run --release` | Run in release mode |
| `flutter build apk` | Build Android APK |
| `flutter build ios` | Build iOS app |
| `flutter clean` | Clean build files |
| `flutter doctor` | Check environment setup |

## Troubleshooting

### First time setup not working?
```bash
flutter clean
flutter pub get
flutter run
```

### Check your environment
```bash
flutter doctor -v
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── exercise/              # Exercise tracking logic
│   ├── exercise_base.dart
│   └── squat.dart
└── utils/                 # Utility functions
    ├── debouncer.dart
    ├── pose_math_helpers.dart
    └── pose_smoother.dart
```

## Dependencies

- `camera` - Camera access
- `google_mlkit_pose_detection` - AI pose detection
- `permission_handler` - Runtime permissions

## Contributing

1. Create a new branch: `git checkout -b feature/your-feature`
2. Make your changes
3. Test on device: `flutter run`
4. Commit: `git commit -m "Add your feature"`
5. Push: `git push origin feature/your-feature`
6. Create a Pull Request
