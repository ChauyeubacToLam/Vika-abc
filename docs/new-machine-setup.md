# New Mac setup — Vika runbook

Everything to do on a fresh MacBook to work on Vika. Plain markdown on purpose: on a bare machine you
can't run lavish/npx yet (installing Node is a step below), so this bootstrap doc must read with zero
tooling. Work top to bottom.

> Things a `git clone` does NOT give you: the agent-memory symlink, gitignored secrets, and the whole
> toolchain. Those are the point of this doc.

## 0. Base toolchain
```bash
xcode-select --install                      # Apple CLT (git, clang)
# Install Xcode from the App Store, then:
sudo xcodebuild -license accept
brew install --cask xcode                    # or App Store; needed for iOS builds
brew install cocoapods gh node               # pods (iOS), gh (git/PRs), node (npx → lavish)
```

## 1. Flutter via FVM (pinned to 3.38.8 — see .fvmrc)
```bash
brew tap leoafarias/fvm && brew install fvm
# after cloning the repo (step 2), inside it:
fvm install 3.38.8 && fvm use 3.38.8
fvm flutter doctor                           # resolve anything red (esp. Xcode / CocoaPods)
```

## 2. Clone the repo
```bash
mkdir -p ~/project && cd ~/project
gh repo clone <your-vika-remote> vika && cd vika
```

## 3. Restore gitignored secrets (NOT in the clone)
Copy from the old Mac (or your password manager). Currently just one file:
```
assets/env/app.env        # Supabase + Viettel TTS keys. Template: assets/env/app.env.example if present.
```
If you later re-add Android release signing, also restore `android/key.properties` + the `*.keystore`.

## 4. Build deps
```bash
fvm flutter pub get
cd ios && pod install && cd ..
fvm flutter run                              # sanity check on a connected iPhone / simulator
```

## 5. Claude Code agent-memory symlink  ⭐ the non-obvious one
Vika's cross-agent memory lives in `docs/agent-memory/` (in git). Claude Code's private auto-memory dir
is a **symlink** to it — that symlink lives in `~/.claude`, so it is per-machine and must be recreated.
Run Claude Code once in the repo first (it creates `~/.claude/projects/<slug>/`), then:
```bash
cd ~/project/vika
SLUG=$(pwd | sed 's:/:-:g')                   # project path with "/" → "-"
MEM="$HOME/.claude/projects/$SLUG/memory"
mkdir -p "$(dirname "$MEM")"
rm -rf "$MEM"                                 # drop the empty memory dir Claude just made
ln -s "$PWD/docs/agent-memory" "$MEM"
ls -ld "$MEM"                                 # expect:  …/memory -> …/vika/docs/agent-memory
```
If the folder name differs, check `~/.claude/projects/` for the dir Claude actually created and point
that one's `memory` at `docs/agent-memory`. Verify: next Claude session should still recall memories.

## 6. Voice dictation app
<!-- TODO(nam): confirm exact app name + install command/link -->
Install the Whisper-based dictation app used to talk into the chat instead of typing.
Candidates if starting fresh: **superwhisper**, **MacWhisper**, or **VoiceInk** (open source).
```bash
# brew install --cask <app>     # fill in the one you use
```

## 7. Nice-to-haves
```bash
npx -y lavish-axi --help                      # warm the lavish CLI cache (HTML review artifacts)
# Sign in: gh auth login   ·   Claude Code   ·   Supabase (if you use the CLI)
```

---
Keep this current: when a new must-do step appears (a new secret, a tool, a pin bump), add it here.
