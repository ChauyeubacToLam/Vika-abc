# Cleanup Audit Report

Generated: 2026-05-13
Branch: `data_mitigation`
Total candidate files (Dart): 17
Total candidate native files: 1 directory
Total naming changes proposed: 3
Total documentation files flagged stale: 1

**This is REPORT ONLY. No files have been modified or deleted. Awaiting approval before pass 2.**

---

## Section A — Dart orphan files

Methodology: for every `.dart` file under `lib/screens/`, `lib/widgets/`,
`lib/services/`, `lib/exercise/`, `lib/pose/`, `lib/utils/`, `lib/models/`,
`lib/theme/`, `lib/debug/`, `lib/data/`, `lib/interpreter/`, `lib/config/`,
`lib/app/`: (1) grep for `import '<basename>'` across `lib/`, (2) grep
each top-level public symbol across `lib/` excluding the file's own path.
Files with zero hits on both checks are candidates. Screen files
additionally checked against route map (`lib/main.dart`,
`lib/screens/main_shell.dart`).

### LOW risk — recommended for deletion

- **lib/widgets/accent_bar_card.dart** — `AccentBarCard`
  - Last commit: 2026-03-31 onboarding done
  - Why: 0 imports of basename; `AccentBarCard` 0 external refs. Part of
    pre-v5 onboarding widget set.
  - Recommendation: DELETE

- **lib/widgets/glow_ring.dart** — `GlowRing`
  - Last commit: 2026-03-31 onboarding done
  - Why: 0 imports; `GlowRing` 0 external refs.
  - Recommendation: DELETE

- **lib/widgets/insight_carousel.dart** — `InsightCarousel`
  - Last commit: 2026-03-31 onboarding done
  - Why: 0 imports; 0 external refs.
  - Recommendation: DELETE

- **lib/widgets/pose_silhouette.dart** — `PoseSilhouette`
  - Last commit: 2026-03-31 onboarding done
  - Why: 0 imports; 0 external refs.
  - Recommendation: DELETE

- **lib/widgets/section_head.dart** — `SectionHead`
  - Last commit: 2026-03-31 onboarding done
  - Why: 0 imports; 0 external refs.
  - Recommendation: DELETE

- **lib/widgets/stat_card.dart** — `StatCard`
  - Last commit: 2026-03-31 onboarding done
  - Why: 0 imports; 0 external refs.
  - Recommendation: DELETE

- **lib/widgets/vf_primitives.dart** — `VFNavGlyph`, `VFGradientAvatar`,
  `VFNavIcon`, `VFGrainOverlay`
  - Last commit: 2026-03-31 onboarding done
  - Why: 0 imports; none of the four exports referenced anywhere.
  - Recommendation: DELETE

- **lib/screens/auth/login_screen.dart** — `VikaLoginPanel`, `LoginScreen`
  - Last commit: 2026-04-15 "done rest screen + UI + login google"
  - Why: 0 imports of basename; neither class referenced outside file. No
    route mapping. Auth currently lives outside the app entry — V5 sign-up
    is handled in `s13_signup.dart`, not via a dedicated login screen.
  - Recommendation: DELETE (cascades — see magic_link_sent_screen.dart)

- **lib/screens/auth/magic_link_sent_screen.dart** — `MagicLinkSentScreen`
  - Last commit: 2026-05-08 landscape ready
  - Why: imported ONLY by `lib/screens/auth/login_screen.dart`, which is
    itself an orphan candidate. Cascade orphan.
  - Recommendation: DELETE together with login_screen.dart (and the empty
    `lib/screens/auth/` directory it leaves behind).

- **lib/screens/exercise/splash_screen.dart** — `SplashScreen`
  - Last commit: 2026-04-19 "Done rest + summary page + datapipe"
  - Why: 0 imports of basename; `SplashScreen` only referenced inside
    `post_exercise_data.dart` in a code COMMENT. No route mapping.
  - Recommendation: DELETE

- **lib/screens/exercise/widgets/depth_chart.dart** — `DepthChart`,
  `DepthBarDatum`
  - Last commit: 2026-05-02 "first round"
  - Why: 0 imports; 0 external refs.
  - Recommendation: DELETE

- **lib/screens/exercise/widgets/issue_question.dart** — `IssueQuestion`
  - Last commit: 2026-05-02 "first round"
  - Why: 0 imports; 0 external refs.
  - Recommendation: DELETE

- **lib/screens/exercise/widgets/metric_chip.dart** — `MetricChip`,
  `MetricChipState`
  - Last commit: 2026-05-02 "first round"
  - Why: 0 imports; 0 external refs.
  - Recommendation: DELETE

- **lib/screens/exercise/widgets/shareable_card.dart** — `ShareableCard`
  - Last commit: 2026-05-02 "first round"
  - Why: 0 imports; 0 external refs.
  - Recommendation: DELETE

### MEDIUM risk — review needed

- **lib/screens/home_screen.dart** — `HomeScreen`
  - Last commit: 2026-05-08 "landscape ready"
  - Why: 0 imports of basename; `HomeScreen` (as a class, not the literal
    string `DashboardHomeScreen`) has 0 external refs in `lib/`. Mentions
    in `data/home_mock.dart`, `widgets/home/*` are all comment-only and
    refer to the screen conceptually. Not in any route. The actually-
    mounted home tab is `DashboardHomeScreen` in
    `lib/screens/dashboard_home_screen.dart`.
  - Why MEDIUM: touched 5 days ago in a commit (`landscape ready`) that
    spanned ~10 files including the active orientation/landscape work.
    Author may have intentionally kept it warm. Worth confirming before
    deletion.
  - Recommendation: DELETE if Nam confirms it is superseded by
    DashboardHomeScreen (high confidence based on `lib/main.dart:280` →
    `MainShell()` → `DashboardHomeScreen`).

- **lib/theme/tokens/radii.dart** — `VikaRadius`
  - Last commit: 2026-05-10 "finialized UI"
  - Why: 0 imports; `VikaRadius` 0 external refs. Sibling
    `lib/theme/tokens/elevation.dart` IS imported (by colors_light /
    responsive). The radii token was apparently authored but never wired.
  - Why MEDIUM: 3 days old, part of the same "finialized UI" commit as
    several files that ARE wired. Could be intentionally staged.
  - Recommendation: REVIEW. If not staged for wiring, DELETE.

- **lib/theme/tokens/spacing.dart** — `VikaSpace`
  - Last commit: 2026-05-10 "finialized UI"
  - Why: 0 imports; `VikaSpace` 0 external refs. Only mention in
    `responsive.dart` is a comment.
  - Why MEDIUM: 3 days old, same situation as radii.dart.
  - Recommendation: REVIEW. If not staged for wiring, DELETE.

### HIGH risk — do not delete without manual verification

None detected. No `Navigator.pushNamed("/...")` string keys, asset-name
reflective lookups, or non-Dart references were found pointing at any
candidate.

### Verified NOT orphaned (sanity checks)

These were checked because their position or naming made them look
suspect; all are reachable.

- `lib/screens/onboarding/onboarding_data.dart` — imported by ~18 v5
  files + services
- `lib/screens/onboarding/onboarding_assessment_thresholds.dart` —
  imported by v5 models + screens
- `lib/data/*_mock.dart` — each imported 1–15× across home/plan/progress
  /profile/library widgets and screens
- `lib/theme/vf_theme.dart` — `VFTheme.*` used heavily across
  `lib/main.dart`, `lib/screens/exercise/executive_summary_page.dart`.
  See Section C for the `VikaIvory.fontFamily` naming change inside it.
- `lib/services/viettel_tts_service.dart` — `ViettelTTSService` is
  instantiated in `lib/exercise/exercise_base.dart:128` and called from
  ~10 sites in the same file. The mp3 audio bank under `assets/audio/`
  is its asset cache. Live.
- `lib/services/squat_voice_coach.dart`, `squat_voice_assets.dart`,
  `queued_asset_voice_player.dart` — wired through
  `lib/exercise/squat/squat.dart:194` `createVoiceCoach()`.

---

## Section B — Confirmation of known suspected orphans

1. **lib/screens/home_screen.dart** — CONFIRMED orphan.
   `MainShell._MainShellState.build` (main_shell.dart:77–89) populates
   the IndexedStack with `DashboardHomeScreen`, `PlanScreen`,
   `ProgressScreen`, `ProfileScreen`. `HomeScreen` is never instantiated.
   See MEDIUM list above.

2. **lib/screens/onboarding/onboarding_screen.dart** + `pages/` directory
   — **ALREADY GONE**. `ls lib/screens/onboarding/` returns only `v5/`,
   `onboarding_data.dart`, `onboarding_assessment_thresholds.dart`. No
   action needed; both `onboarding_data.dart` and
   `onboarding_assessment_thresholds.dart` are live (imported by v5).
   `lib/main.dart:21,159,278` routes exclusively to
   `V5OnboardingNavigator`.

3. **android/app/src/main/kotlin/com/vikavn/vika/MainActivity.kt** —
   CONFIRMED orphan.
   - `android/app/build.gradle.kts:33` `namespace = "com.vikavn.app"`
   - `android/app/build.gradle.kts:47` `applicationId = "com.vikavn.app"`
   - `AndroidManifest.xml` uses relative `.MainActivity` → resolves to
     `com.vikavn.app.MainActivity` (which exists at
     `kotlin/com/vikavn/app/MainActivity.kt`).
   - The `.../vika/MainActivity.kt` file is a 4-line shell in the wrong
     package and is not selected by the manifest. Stale from the
     `com.vikavn.vika → com.vikavn.app` rename.
   - Recommendation: DELETE the entire
     `android/app/src/main/kotlin/com/vikavn/vika/` directory.

---

## Section C — Naming cleanup

### C1. `lib/screens/onboarding/v5/v5_theme.dart` — `GoogleFonts.inter` → BeVietnamPro

- Call sites in this file: 1 (`v5_theme.dart:51` inside `text()`)
- The comment at v5_theme.dart:48–50 explains the choice was a fallback
  ("Geist isn't shipped in google_fonts yet; Inter is its predecessor").
  But the rest of the app uses `BeVietnamPro`, which is bundled and
  shipped in `pubspec.yaml`.
- BeVietnamPro weight coverage required by V5 (400/500/700/800): all
  present in `assets/fonts/be_vietnam_pro/` AND declared in
  `pubspec.yaml:`fonts:` block (lines 56–94). Weights 400, 400 italic,
  500, 500 italic, 600, 600 italic, 700, 700 italic, 800, 800 italic
  are all registered. **Safe to swap.**
- Proposed change: replace the `GoogleFonts.inter(...)` call with a
  plain `TextStyle(fontFamily: 'BeVietnamPro', fontSize: size,
  fontWeight: weight, color: color, letterSpacing: letterSpacing,
  height: height)`. Drop the `import 'package:google_fonts/...'` line.
- Recommendation: APPLY

### C2. `lib/theme/vf_theme.dart` — `VikaIvory.fontFamily` `'PlusJakartaSans'` → `'BeVietnamPro'`

- Definition: `vf_theme.dart:499`
  `static const String fontFamily = 'PlusJakartaSans';`
- Call sites of `VikaIvory.fontFamily` across `lib/`: 15 (active-exercise
  page, ivory_chrome, debug_panel). All 15 propagate this constant
  directly into `TextStyle(fontFamily: ...)`.
- Cross-check for the literal string `'PlusJakartaSans'` elsewhere in
  the codebase: 1 hit, the definition itself. No other references.
- No `PlusJakartaSans` font asset exists in `assets/fonts/`. Currently
  all VikaIvory text falls back to system sans-serif (San Francisco /
  Roboto). Switching to `'BeVietnamPro'` aligns the active-exercise
  screen with the rest of the app and uses the bundled font.
- Proposed change: one-line edit to
  `static const String fontFamily = 'BeVietnamPro';`
- Recommendation: APPLY. No other changes needed — all 15 call sites
  reference the constant, not the literal.

### C3. `google_fonts` package removal from `pubspec.yaml`

- After C1 + C2, remaining `GoogleFonts.*` call sites:
  - `lib/screens/exercise/rest_screen.dart` — 1 call:
    `GoogleFonts.oswald(...)` at line 270
  - `lib/screens/exercise/executive_summary_page.dart` — 5 calls
    (`GoogleFonts.dmSans` ×4, `GoogleFonts.oswald` ×1)
  - `lib/theme/vf_theme.dart` — 3 calls (`GoogleFonts.dmSans(...)` at
    174 and 281, `GoogleFonts.dmSansTextTheme(...)` at 265). These are
    the SHARED app text theme; they style every legacy VFTheme screen.
- `google_fonts` package CANNOT be removed in this cleanup pass. 9 call
  sites remain across 3 files, spanning the active-exercise rest screen,
  the executive summary, and the global VFTheme text theme.
- Recommendation: KEEP `google_fonts: ^6.2.1` in `pubspec.yaml`. Leaving
  pubspec untouched.

### C4. (BONUS) Stale instructional comment in `pubspec.yaml`

- `pubspec.yaml:48–66` contains an "**ACTION REQUIRED**" comment block
  telling the reader to drop the BeVietnamPro `.ttf` files into
  `assets/fonts/be_vietnam_pro/` and uncomment the `fonts:` block. Both
  things are already done: 18 `.ttf` files are on disk and the `fonts:`
  block on lines 56–94 IS uncommented.
- Recommendation: trim the obsolete instruction comment (lines roughly
  47–67) down to a one-line header. NOT part of the deletion pass —
  flagging for a follow-up if Nam wants tidier pubspec comments.

---

## Section D — Asset orphans

### D1. `assets/images/`

- Files on disk: `body_male.png`, `body_female.png`
- References: both used in
  `lib/widgets/progress/body_heat_map.dart:86–87`.
- **No orphans.**

### D2. `assets/audio/` (top-level mp3 bank — ViettelTTSService cache)

- 30 numbered files (`1.mp3`–`30.mp3`) + 27 phrase files.
- Cross-checked against the `_assetMap` in
  `lib/services/viettel_tts_service.dart:64–129`.
- **All mp3 files on disk are referenced** by the assetMap.
- BUG (separate from orphans) — assetMap entries pointing at MISSING
  files:
  - `"nhớ xuống thấp hơn": "nho_xuong_thap_hon.mp3"` (line 117) — file
    not present in `assets/audio/`. Only the `.wav` version exists in
    `assets/audio/squat/`.
  - `"nhớ giữ gót chân": "nho_giu_got_chan.mp3"` (line 118) — file not
    present.
  - `"nhớ chậm lại": "nho_cham_lai.mp3"` (line 119) — file not present.
  - Impact: any code path that speaks one of these three Vietnamese
    phrases through `ViettelTTSService` will silently fall back to the
    network TTS API (Viettel cloud) rather than play a cached asset.
    Not blocking, but flagging as a separate bug from the cleanup pass.

### D3. `assets/audio/squat/` (wav bank — SquatVoiceCoach)

- 25 files on disk (15 numbered + 10 phrase).
- Cross-checked against `SquatVoiceAssets.files` in
  `lib/services/squat_voice_assets.dart:5–31`.
- 25 map entries, all 25 files present, no map entry points at a
  missing file.
- **No orphans. No bugs.**

---

## Section E — Documentation flagged stale (NO DELETIONS)

- **docs/min_confidence_audit.md** (last touched 2026-05-05) — STALE.
  Audits a constant `MIN_CONFIDENCE = 0.92` defined at
  `lib/exercise/exercise_base.dart:67`. That constant no longer exists.
  The current file (lines 84, 92) defines `MIN_PRESENCE = 0.7` and
  `MIN_VISIBILITY = 0.3`, which were swapped in via the
  "presence_filter_swap" change documented in
  `docs/presence_filter_swap_report.md`.
  - Flagged. Per directive, NOT deleted in this pass.

Other docs in `/docs/` either describe still-current architecture
(`PREMIUM_IVORY_WIRING.md`, `contrast-report.md`, `ui-system-audit.md`,
`ui-system-validation.md`) or are historical change reports that are
fine to retain (`*_orientation_*`, `ios_native_pose_rewrite_report.md`,
`native_segmentation_2a_report.md`, `presence_filter_swap_report.md`).

---

## Recommended deletion order (if all approved)

Group into focused commits so `fvm flutter analyze` can verify after
each. Suggested grouping:

1. **Commit 1 — remove legacy onboarding-era widgets** (7 files, all
   2026-03-31, LOW risk):
   - `git rm lib/widgets/accent_bar_card.dart`
   - `git rm lib/widgets/glow_ring.dart`
   - `git rm lib/widgets/insight_carousel.dart`
   - `git rm lib/widgets/pose_silhouette.dart`
   - `git rm lib/widgets/section_head.dart`
   - `git rm lib/widgets/stat_card.dart`
   - `git rm lib/widgets/vf_primitives.dart`

2. **Commit 2 — remove unused executive-summary widgets** (4 files, all
   2026-05-02, LOW risk):
   - `git rm lib/screens/exercise/widgets/depth_chart.dart`
   - `git rm lib/screens/exercise/widgets/issue_question.dart`
   - `git rm lib/screens/exercise/widgets/metric_chip.dart`
   - `git rm lib/screens/exercise/widgets/shareable_card.dart`

3. **Commit 3 — remove unused auth screens** (2 files):
   - `git rm lib/screens/auth/login_screen.dart`
   - `git rm lib/screens/auth/magic_link_sent_screen.dart`
   - `rmdir lib/screens/auth/` (if empty)

4. **Commit 4 — remove pre-MainShell HomeScreen and exercise splash**
   (2 files, MEDIUM risk — final confirmation required for home_screen):
   - `git rm lib/screens/home_screen.dart`
   - `git rm lib/screens/exercise/splash_screen.dart`

5. **Commit 5 — remove unused theme tokens** (2 files, MEDIUM risk —
   confirm not staged for upcoming wiring):
   - `git rm lib/theme/tokens/radii.dart`
   - `git rm lib/theme/tokens/spacing.dart`

6. **Commit 6 — remove stale Android Kotlin package directory** (1
   directory):
   - `git rm -r android/app/src/main/kotlin/com/vikavn/vika`

7. **Commit 7 — naming cleanup, no behavior change**:
   - `lib/screens/onboarding/v5/v5_theme.dart`: replace
     `GoogleFonts.inter(...)` with `TextStyle(fontFamily:
     'BeVietnamPro', ...)`. Drop `import
     'package:google_fonts/google_fonts.dart';`.
   - `lib/theme/vf_theme.dart`: change `VikaIvory.fontFamily` from
     `'PlusJakartaSans'` to `'BeVietnamPro'`. No call-site changes
     (all 15 reference the constant, not the literal).
   - Leave `google_fonts` in pubspec — 9 call sites remain.

After each commit, run `fvm flutter analyze`. Per the protocol: if it
fails, stop and report — do not patch other files.

---

## Items intentionally NOT proposed for deletion

- `lib/theme/vf_theme.dart` (legacy `VFTheme`) — still used by ~20
  screens, per directive.
- All `lib/exercise/**/*_metric_base.dart` files — base classes for
  active metric subclasses.
- `lib/pose/*` — active pipeline.
- All `lib/screens/onboarding/v5/**` — active onboarding flow.
- `pubspec.yaml` `google_fonts:` dependency — 9 remaining call sites.
- `/docs/min_confidence_audit.md` — flagged stale but per directive
  docs are not deleted in this pass.
- Anything under `ios/`, `macos/`, `windows/`, `linux/`.

---

## Notes / open questions for Nam

1. **home_screen.dart** was touched in the 2026-05-08 "landscape ready"
   commit alongside files that ARE active. Confirm before commit 4 that
   `landscape ready` was a sweep across all .dart files (touch-up) and
   not intentional retention of `HomeScreen`.
2. **radii.dart / spacing.dart** are 3 days old and unused. Are they
   tokens you authored for upcoming work? If yes, leave them; if no,
   commit 5 cleans them up.
3. **pubspec.yaml** lines 47–67: the "ACTION REQUIRED" comment block is
   outdated (fonts are already bundled and registered). Worth trimming
   in a follow-up but not part of this audit.
