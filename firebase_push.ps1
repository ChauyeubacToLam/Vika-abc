# Push a release build to Firebase App Distribution.
#
# One-time prereqs:
#   1) Install Firebase CLI:  npm install -g firebase-tools
#      (or download firebase-tools-instant-win.exe, rename to firebase.exe, add to PATH)
#   2) firebase login
#   3) Firebase console > create project > add Android app (com.vikavn.app) >
#      copy the App ID, and create a tester group with tester emails.

# ---- FILL THESE IN ----
$AppId = "1:384490483020:android:bc4bfcb00b7e7a86cdb3e9"          # e.g. 1:1234567890:android:abc123def456
$Group = "tester"                              # your tester group name in Firebase
# -----------------------

$repo = "C:\Nam career\Projects\Vinafit_mobile"
$Notes = "Android test build $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

Set-Location $repo

$fb = (Get-Command firebase -ErrorAction SilentlyContinue).Source
if (-not $fb) {
  $prefix = (npm config get prefix 2>$null | Select-Object -First 1)
  if ($prefix) {
    $cand = Join-Path $prefix.Trim() "firebase.cmd"
    if (Test-Path $cand) { $fb = $cand }
  }
}
if (-not $fb) {
  Write-Host "Firebase CLI not found. Install it (npm install -g firebase-tools) and run 'firebase login' first."
  exit 1
}
if ($AppId -eq "PASTE_YOUR_FIREBASE_APP_ID") {
  Write-Host "Set `$AppId at the top of this script (Firebase console > Project settings > General)."
  exit 1
}

Write-Host "Building release APK (arm64, split per ABI = lighter download for testers)..."
flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed."; exit 1 }

$apk = Join-Path $repo "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
if (-not (Test-Path $apk)) { Write-Host "APK not found at $apk"; exit 1 }

Write-Host "Uploading to Firebase App Distribution..."
& $fb appdistribution:distribute $apk --app $AppId --groups $Group --release-notes $Notes
if ($LASTEXITCODE -eq 0) { Write-Host "Done. Testers in '$Group' will get an email invite." }
else { Write-Host "Upload failed. If it's an auth error, run 'firebase login' and retry." }
