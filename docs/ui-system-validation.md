# UI system — validation matrix

Manual QA pass for the Phase 1–7 changes. Run **after** dropping the
Be Vietnam Pro `.ttf` files into `assets/fonts/be_vietnam_pro/` and
running `flutter pub get`.

## Required font files (drop these in)

```
assets/fonts/be_vietnam_pro/
  BeVietnamPro-Regular.ttf
  BeVietnamPro-Italic.ttf
  BeVietnamPro-Medium.ttf
  BeVietnamPro-MediumItalic.ttf
  BeVietnamPro-Bold.ttf
  BeVietnamPro-BoldItalic.ttf
  BeVietnamPro-ExtraBold.ttf
  BeVietnamPro-ExtraBoldItalic.ttf
```

Free download: https://fonts.google.com/specimen/Be+Vietnam+Pro

## Device + condition matrix

Test the HomeScreen on **every** combination below. Note any clipping,
overflow, illegibility, or dark-mode orphans. Capture screenshots into
`docs/screenshots/<device>-<theme>-<scale>.png`.

| Device | Resolution | Theme | Text scale | Pass / fail |
|---|---|---|---|---|
| iPhone SE (3rd gen)   | 375 × 667 | Light | 1.0× | _____ |
| iPhone SE (3rd gen)   | 375 × 667 | Light | 1.3× | _____ |
| iPhone SE (3rd gen)   | 375 × 667 | Dark  | 1.0× | _____ |
| iPhone 14             | 390 × 844 | Light | 1.0× | _____ |
| iPhone 14             | 390 × 844 | Light | 1.3× | _____ |
| iPhone 14             | 390 × 844 | Dark  | 1.0× | _____ |
| iPhone 15 Pro Max     | 430 × 932 | Light | 1.0× | _____ |
| iPhone 15 Pro Max     | 430 × 932 | Dark  | 1.0× | _____ |
| Pixel 7               | 412 × 915 | Light | 1.0× | _____ |
| Pixel 7               | 412 × 915 | Dark  | 1.0× | _____ |
| Galaxy A / Redmi      | 360 × 640 | Light | 1.0× | _____ |
| Galaxy A / Redmi      | 360 × 640 | Light | 1.3× | _____ |

## Vietnamese stress strings

Render in HomeScreen at every breakpoint. Watch for clipped diacritics
(`ấ ầ ẩ ẫ ậ ổ ỗ ộ`) — they should sit fully above the line cap.

| String                          | Component                | Size / weight    | OK? |
|---------------------------------|--------------------------|------------------|-----|
| `Bắt đầu Buổi 03`               | HeroDayCard CTA          | 14sp / 800 italic|     |
| `Cốt lõi`                       | Stat tile value          | 14sp / 800       |     |
| `Khởi đầu`                      | Phase label              | 12sp / 700       |     |
| `Đẩy mạnh`                      | Phase label              | 12sp / 700       |     |
| `Toàn thân nhẹ`                 | HeroDayCard title        | 46sp / 800 italic|     |
| `Thứ Sáu · 8 tháng 5 · Buổi 03` | GreetingBlock day label  | 13sp / 500       |     |
| `Muốn ngủ ngon hơn và…`         | JournalEntry quote       | 14sp / 600 italic|     |
| `HÔM NAY · BUỔI 03`             | HeroDayCard eyebrow      | 9sp / 800 caps   |     |

If any string clips: file is `home_mock.dart` (mock data) or the
specific widget's TextStyle. Bump `height:` ≥ 1.45 for body or 1.15 for
display. See `docs/contrast-report.md` and inline comments in
`lib/theme/typography.dart` for the height rules.

## Functional checks

- [ ] Tap "Bắt đầu Buổi 03" CTA — light haptic fires, route pushes to
      `/exercise` with the Squat definition.
- [ ] Tap calendar / avatar icon in WordmarkHeader — 48pt hit target
      registers anywhere within the visible 38px circle, *plus* the
      ~5pt invisible padding around it.
- [ ] VoiceOver / TalkBack: announces "Vika, header" + announces hero
      card with the full summary string + announces "12 ngày liên tiếp"
      on streak ring.
- [ ] Toggle system dark mode mid-screen — page bg, hero cards, ink,
      borders all flip cleanly. No orphan light-mode color anywhere.
      (Plan/Progress/Profile tabs WILL show orphans — they're intended
      for a follow-up PR. HomeScreen is the proof-of-life.)
- [ ] Set iOS Dynamic Type to AX5 (largest) — text scales up but caps
      at 1.3× of baseline (per `VikaType.clampTextScaler`). Layout
      doesn't overflow.
- [ ] Set iOS Reduce Motion — TODO: the prompt asked for this. Currently
      not yet wired into PageView fade / streak ring animation.
      **Follow-up.**

## Known gaps (deferred to follow-up PRs)

1. **Plan / Progress / Profile / Library** still reference
   `VikaIvoryMain.X` (which is light-only). Their dark-mode appearance
   will be broken. HomeScreen-only proof-of-life per the master plan.
2. **Pixel-literal scaling** — the `Responsive` class is wired but
   `r.w(N)` is NOT yet applied across the 30+ pixel literals in the
   Home stack. A follow-up pass will replace `EdgeInsets.all(22)` →
   `EdgeInsets.all(r.w(22))`. The screen still renders correctly —
   just isn't fluid across the iPhone size range yet.
3. **MainShell status bar overlay** — currently hardcoded to dark
   icons. Should flip per theme. Quick follow-up.
4. **Reduced-motion gate** — animations don't yet check
   `MediaQuery.disableAnimations`. Quick follow-up.
5. **Touch targets** — fixed on WordmarkHeader. Other icon buttons
   (in IvoryBottomNav, Library sheet close, etc.) still at 38px visual
   = 38px hit. Follow-up pass.

## Phase deliverable map

| Master prompt deliverable | File / location | Status |
|---|---|---|
| 1. `docs/ui-system-audit.md` | `docs/ui-system-audit.md` | ✓ approved |
| 2. `design.md` updates | (skipped per user request) | n/a |
| 3. `docs/contrast-report.md` | `docs/contrast-report.md` | ✓ |
| 4. `lib/theme/tokens/` | 5 token files in folder | ✓ |
| 5. `lib/theme/typography.dart` | created | ✓ |
| 6. `lib/theme/responsive.dart` | created (not yet applied to widgets) | partial |
| 7. `lib/theme/app_theme.dart` | n/a — see `lib/theme/app_colors.dart` instead | * |
| 8. Updated `pubspec.yaml` | font assets declared | ✓ |
| 9. Refactored HomeScreen | `dashboard_home_screen.dart` + Home widgets | ✓ |
| 10. Screenshots | `docs/screenshots/` (empty — manual QA pending) | pending |
| 11. PR description | this doc + the audit doc | ✓ |

**\*** Per the audit: legacy screens (auth, exercise camera, onboarding,
rest, summary) still depend on `VFTheme.lightTheme` via
`MaterialApp.theme`. Switching to a unified light+dark `ThemeData`
would migrate them too — out of scope for this PR. The
`VikaColors.of(context)` accessor lets Premium Ivory main-app screens
be dark-mode-aware without disturbing the legacy ones.
