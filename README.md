# Vika 💪

A Flutter fitness app with AI-powered pose detection for exercise tracking.

---

## 🚀 For New Team Members - Start Here!

### Step 1: One-Time Installs

| What to Install | Why You Need It | Download Link |
|-----------------|-----------------|---------------|
| **Android Studio** | Android SDK + JDK (required for builds) | [📥 Download](https://developer.android.com/studio) |
| **Flutter SDK** | Framework (includes Dart) | [📥 Download](https://docs.flutter.dev/get-started/install) |
| **VS Code** | Code editor | [📥 Download](https://code.visualstudio.com/) |

> ✅ You do NOT need to install Dart or Java separately.

---

### Step 2: Add Flutter to PATH

Flutter won't work until your system knows where to find it.

**Windows:**
- Open Start → search "environment variables"
- Edit the **User** `Path` variable
- Add the path to Flutter's `bin` folder, e.g.: `C:\src\flutter\bin`
  - This depends on where you extracted Flutter. It's wherever you put the `flutter` folder + `\bin`
- Click OK, then **close and reopen your terminal**

**Mac:**
```bash
# Replace /path/to/flutter with where you extracted Flutter, e.g. ~/dev/flutter
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

Verify Flutter works:
```bash
flutter --version
```

---

### Step 3: Accept Android Licenses

Android requires you to accept its SDK licenses before building. Run:

```bash
flutter doctor --android-licenses
```

Press `y` and Enter for every prompt until it says "All SDK package licenses accepted."

Then verify everything is green:
```bash
flutter doctor
```

Make sure you see ✅ for both **Flutter** and **Android toolchain**. Fix any issues it flags before continuing.

---

### Step 4: Install FVM (Flutter Version Manager)

This ensures everyone runs the exact same Flutter version.

```bash
dart pub global activate fvm
```

Then add FVM to your PATH:

**Windows:**
- Open the same "environment variables" window from Step 2
- Edit the **User** `Path` variable again
- Add: `C:\Users\[YOUR_NAME]\AppData\Local\Pub\Cache\bin`
- Click OK, then **close and reopen your terminal**

**Mac:**
```bash
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

Verify it works:
```bash
fvm --version
```

---

### Step 5: Set JAVA_HOME

Gradle needs to know where Android Studio's JDK is.

**Windows** — run this in PowerShell:
```powershell
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Android\Android Studio\jbr", [System.EnvironmentVariableTarget]::User)
```

**Mac** — run this in terminal:
```bash
echo 'export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"' >> ~/.zshrc
source ~/.zshrc
```

Close and reopen your terminal after running this.

---

### Step 6: Clone and Run

```bash
# Clone the project
git clone https://github.com/Seaw24/Vika.git
cd Vika

# Install the pinned Flutter version
fvm install

# Get dependencies
fvm flutter pub get

# Connect your phone or start an emulator, then:
fvm flutter run
```

**First build takes 3-5 minutes. Every build after that is fast.** 🎉

---

## 📱 How to Test on Your Phone

### Android Phone:
1. Go to Settings → About Phone → tap **Build Number** 7 times
2. Go back to Settings → Developer Options → enable **USB Debugging**
3. Connect phone via USB
4. Run `fvm flutter devices` to confirm it's detected
5. Run `fvm flutter run`

### Android Emulator:
1. Open Android Studio → Device Manager → Create Virtual Device
2. Choose Pixel 6 → download a system image → Finish
3. Start the emulator
4. Run `fvm flutter run`

### iOS (Mac only):
1. Install Xcode from the App Store
2. Run:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```
3. Open Simulator or connect an iPhone
4. Run `fvm flutter run`

---

## 🛠️ Common Commands

| Command | What It Does |
|---------|--------------|
| `fvm flutter pub get` | Download dependencies |
| `fvm flutter run` | Run app on device |
| `fvm flutter devices` | List connected devices |
| `fvm flutter clean` | Clear build cache |
| `fvm flutter doctor` | Check installation health |

---

## ❓ Troubleshooting

### "flutter is not recognized" / "flutter: command not found"
→ Flutter is not in your PATH. Re-do Step 2 for your OS, close and reopen the terminal after.

### "fvm is not recognized" / "fvm: command not found"
→ FVM is not in your PATH. Re-do Step 4 for your OS, close and reopen the terminal after.

### "No connected devices"
→ Connect a phone with USB Debugging ON, or start an emulator in Android Studio.

### Gradle build failed
```bash
fvm flutter clean
fvm flutter pub get
fvm flutter run
```

### "Cannot find Java installation" error
→ JAVA_HOME is not set correctly. Re-do Step 5 for your OS, close and reopen the terminal after.

### Still failing?
```bash
fvm flutter doctor -v
```
Share the full output in the team group chat.

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

1. Pull latest: `git pull origin main`
2. Create your branch: `git checkout -b feature/your-feature-name`
3. Make changes and test: `fvm flutter run`
4. Commit: `git commit -m "feat: your change"`
5. Push: `git push origin feature/your-feature-name`
6. Open a Pull Request on GitHub
