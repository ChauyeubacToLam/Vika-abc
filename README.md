# Vinafit Mobile 💪

A Flutter fitness app with AI-powered pose detection for exercise tracking.

---

## 🚀 For New Team Members - Start Here!

### Step 1: Install These First (One-Time Setup)

| What to Install | Why You Need It | Download Link |
|-----------------|-----------------|---------------|
| **Flutter SDK** | Framework to build the app (includes Dart) | [📥 Download Flutter](https://docs.flutter.dev/get-started/install/windows) |
| **Android Studio** | For Android SDK & Emulator | [📥 Download Android Studio](https://developer.android.com/studio) |
| **VS Code** (recommended) | Code editor | [📥 Download VS Code](https://code.visualstudio.com/) |

> ✅ **Note:** You do NOT need to install Dart separately - it comes with Flutter!

### Step 2: Verify Installation

Open terminal/command prompt and run:
```bash
flutter doctor
```
Make sure you see ✅ for Flutter and Android toolchain.

---

### Step 3: Get the Code & Run (5 minutes)

```bash
# 1. Clone the project
git clone https://github.com/YOUR_USERNAME/vinafit_mobile.git

# 2. Go into the folder
cd vinafit_mobile

# 3. Download all dependencies (automatic!)
flutter pub get

# 4. Connect your phone OR start an emulator, then run:
flutter run
```

**That's it! The app should launch on your device.** 🎉

---

## 📱 How to Test on Your Phone

### Android Phone:
1. Enable **Developer Options** on your phone (tap Build Number 7 times in Settings > About)
2. Enable **USB Debugging** in Developer Options
3. Connect phone via USB cable
4. Run `flutter devices` to check if detected
5. Run `flutter run`

### Android Emulator:
1. Open Android Studio → Device Manager → Create Virtual Device
2. Choose a phone (e.g., Pixel 6) → Download system image → Finish
3. Start the emulator
4. Run `flutter run`

---

## 🛠️ Common Commands

| Command | What It Does |
|---------|--------------|
| `flutter pub get` | Download dependencies |
| `flutter run` | Run app on device |
| `flutter devices` | List connected devices |
| `flutter clean` | Clear cache (fixes most issues) |
| `flutter doctor` | Check if everything is installed |

---

## ❓ Troubleshooting

### "Command not found: flutter"
→ Flutter is not in your PATH. Follow the [installation guide](https://docs.flutter.dev/get-started/install/windows) again.

### "No connected devices"
→ Connect a phone via USB with USB Debugging ON, or start an emulator.

### App won't build / weird errors
```bash
flutter clean
flutter pub get
flutter run
```

### Still not working?
```bash
flutter doctor -v
```
Share the output with the team.

---

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point
├── exercise/              # Exercise tracking logic
│   ├── exercise_base.dart
│   └── squat.dart
└── utils/                 # Helper functions
    ├── debouncer.dart
    ├── pose_math_helpers.dart
    └── pose_smoother.dart
```

---

## 🤝 How to Contribute

1. Pull latest changes: `git pull origin main`
2. Create your branch: `git checkout -b feature/your-feature-name`
3. Make changes & test: `flutter run`
4. Commit: `git commit -m "Add your feature"`
5. Push: `git push origin feature/your-feature-name`
6. Create a Pull Request on GitHub
