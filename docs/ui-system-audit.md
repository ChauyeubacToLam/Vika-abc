# UI System Audit — Phase 0

**Status:** awaiting approval to proceed to Phase 1.

---

## 1. `design.md` / `DESIGN.md` content + conflicts

### What's there
The file at the project root (15.4 kB) documents Vika as **"Premium Ivory"** with these tokens:

- **Colors** — full set matching what Phase 1 of the prompt specifies for `colors_light.dart`. Light tokens are 1:1 between the doc and the prompt. ✓
- **Typography** — currently specifies **Oswald** (display) + **Be Vietnam Pro** (body). Loaded at runtime via `google_fonts` package.
- **Layout / Elevation / Shapes / Components** — well-documented prose.
- **Asset requirements** — explicitly says "Loaded at runtime via the `google_fonts` package … no manual `.ttf` bundling needed."

### Filesystem note
`DESIGN.md` and `design.md` are the same file (macOS case-insensitive HFS). Both `ls` entries return the same inode, identical size. Either name works.

### Conflicts with this prompt
| Topic | DESIGN.md says | Prompt says | Resolution needed |
|---|---|---|---|
| Display family | **Oswald** (sans condensed) | (silent — Be Vietnam Pro only mentioned for body, doesn't specify display) | Keep Oswald or drop it? |
| Italic display family | Oswald italic 700-800 | (silent) | Keep? |
| Font loading strategy | runtime via `google_fonts` | "Do NOT add `google_fonts`" / use bundled .ttf | **Conflict — see #3** |
| Dark mode | not documented | full refined token set in Phase 1 | DESIGN.md needs the dark section added |

### Missing from DESIGN.md (per this prompt)
- Dark theme token set
- Spacing scale (`s2 / s4 / s8 …`)
- Radius scale (`r4 / r8 …`)
- Vietnamese line-height rules
- Touch target rules
- Reference design size (390×844 baseline)
- Adaptive sizing strategy

These all need to land in DESIGN.md as part of Phase 1 work.

---

## 2. Where current ThemeData / TextTheme / color tokens live

- **`lib/theme/vf_theme.dart`** — single 525-line file containing everything:
  - `VFTheme` — legacy jade-green theme (DM Sans). Still used by ~20 screens (auth, exercise, rest, executive summary, onboarding).
  - `VikaIvoryMain` — Premium Ivory token class. Used by all main-app tabs (Home, Plan, Progress, Profile, Library).
  - `VFButton`, `VFScrollBehavior`, `FrostedGlass` — utility widgets.
- `MaterialApp.theme` is set to `VFTheme.lightTheme` (jade theme, not Premium Ivory). Premium Ivory screens reference `VikaIvoryMain.X` directly inside their widgets — they don't go through `Theme.of(context)`.
- **No `darkTheme` defined**. **No `themeMode` set**. ThemeMode defaults to `ThemeMode.system` per Material spec, but there's no dark `ThemeData` for the system to fall back to → app stays light regardless of OS dark mode.

This is a real footgun — tokens are accessed two different ways across the codebase:
- Old/legacy: `Theme.of(context).primaryColor`, `VFTheme.X` static refs, `VFTheme.textStyle(context, ...)` factories
- New: `VikaIvoryMain.X` direct static refs, `GoogleFonts.X(textStyle: ...)` wrappers (this is what the previous turn's work produced)

A unified `Theme.of(context).extension<VikaTokens>()` pattern would replace both.

---

## 3. Font situation (the big conflict)

### `pubspec.yaml`
- `google_fonts: ^6.2.1` is **already a dependency**. Has been since before this redesign. Used by `VFTheme.textStyle` factories via `GoogleFonts.dmSans(...)`.
- The `flutter > fonts:` section is **empty**. No bundled `.ttf` files declared.
- `assets/fonts/` directory exists but is empty (the Plus Jakarta Sans `.ttf` files were removed in an earlier turn).

### Code
- ~150 widget call-sites are wrapped in `GoogleFonts.oswald(textStyle: ...)` or `GoogleFonts.beVietnamPro(textStyle: ...)`. Result of the previous turn's work.
- `VFTheme.textStyle(...)` (legacy) calls `GoogleFonts.dmSans(...)`.
- `MaterialApp.theme.fontFamily` is implicitly DM Sans (via `VFTheme.lightTheme.textTheme = GoogleFonts.dmSansTextTheme(...)` in vf_theme.dart line 265).

### Conflict with prompt
Prompt says:
> **Do NOT add `flutter_screenutil`, `google_fonts`, or any responsive-design package.** Flutter-native + bundled fonts is all we need.

`google_fonts` is already there. Two options:
- **(a) Honor prompt strictly** — remove `google_fonts` from `pubspec.yaml`, bundle `.ttf` files, refactor all ~150 call-sites + VFTheme.textStyle.
- **(b) Keep `google_fonts` since it's already a dependency, but switch to bundled `.ttf` for display+body via the package's `GoogleFonts.asMap` mechanism or just use raw `TextStyle(fontFamily: 'BeVietnamPro')` after declaring in pubspec.**

I recommend **(b)** because:
1. Removing `google_fonts` completely also breaks `VFTheme.textStyle` which is used by 20+ legacy screens.
2. The package can read bundled `.ttf` via the system font fallback if filenames match.
3. Migration cost: a few hours instead of a few days.

But if you want strict (a), say so and I'll plan that scope.

### Display family question
- Prompt's typography (Phase 2) lists **Be Vietnam Pro for everything**, with display1 at 48sp/800/italic.
- DESIGN.md currently says **Oswald** for display.
- Is the spec explicitly switching back to Be Vietnam Pro single-family for display? Or is Oswald still the intended display family and Phase 2 just lists Be Vietnam Pro for body+labels?

**Need explicit answer.** I'd lean toward Be Vietnam Pro single-family — it has italic at 800, supports all the diacritic stacks the prompt is anxious about, and dropping Oswald reduces bundle size and font matching complexity. Oswald is a Latin-Extended font but its diacritic stacks are looser than Be Vietnam Pro's (Be Vietnam Pro was drawn for Vietnamese specifically).

---

## 4. Existing responsive sizing

### `VFTheme.scale(context)` (lib/theme/vf_theme.dart:73)
```dart
static double scale(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width / 393).clamp(0.85, 1.15).toDouble();
}
static double sp(BuildContext context, double size) => size * scale(context);
```

Already exists. Reference width = **393** (iPhone 14 Pro), clamp **[0.85, 1.15]**. Used by ~10 legacy screens via `final s = VFTheme.scale(context); … size: 28 * s`.

### Conflicts with prompt's `Responsive`
Prompt wants:
- Reference **390** (not 393)
- Clamp **[0.92, 1.13]** (tighter than current)
- Methods `r.w(N) / r.h(N) / r.sp(N) / r.gap(N)` and breakpoints `r.isCompact / .isStandard / .isLarge`

Decision needed: replace VFTheme.scale entirely (also affects legacy screens) or have `Responsive` and `VFTheme.scale` coexist temporarily? I recommend replacing — the math is similar enough that the visual diff on legacy screens will be sub-pixel.

### Premium Ivory widgets I built last week
Used **raw pixel values** throughout (e.g. `padding: const EdgeInsets.all(22)`, `width: 36, height: 36`). They are NOT scaled by anything. On iPhone SE (375pt) the Premium Ivory hero cards will overflow horizontally — they're sized for 390pt baseline.

This is the biggest single migration cost in Phase 7. Every widget's pixel literal needs to become `r.w(22)` etc.

---

## 5. SafeArea usage

Inconsistent. Used in 10 screens (counted via grep). Notable patterns:
- `lib/screens/main_shell.dart:99` — `SafeArea(bottom: false, …)`. ✓ correct pattern.
- `lib/screens/home_screen.dart:46` — legacy "exercise selection grid" page (not the new dashboard). Uses `SafeArea` wrapping a Stack.
- `lib/screens/dashboard_home_screen.dart` — new Premium Ivory home tab. **No SafeArea** (the parent MainShell handles it via line 99). ✓ correct.
- `lib/screens/exercise/active_exercise_page.dart` — uses `SafeArea` per-fallback-state, not as a top-level wrapper. Camera fills under status bar intentionally.

**Action for Phase 4**: standardise on parent-screen SafeArea pattern. Remove redundant nested SafeArea wraps.

---

## 6. Current dark mode state

**None.** `MaterialApp.darkTheme` is null. No `ThemeMode` set.

Status bar overlay style is hardcoded to `Brightness.dark` icons (i.e. light status bar) on every screen via `AnnotatedRegion<SystemUiOverlayStyle>`. This will look wrong on warm-dark surfaces if dark mode is added — needs to flip per theme.

The Premium Ivory hero cards already have a **warm-dark surface** (`bgInverse: #1F1812`) and use cream ink on top — so part of the dark visual system is already designed and tested. Migrating this surface to `bg` in dark mode is mostly tonal shift, not redesign.

---

## 7. HomeScreen location

Two files exist:
- **`lib/screens/dashboard_home_screen.dart`** — class `DashboardHomeScreen`. THIS is the active home tab (rendered at index 0 in `MainShell._screens`). 245 lines. Premium Ivory v1, italic display headlines, hero card rail, streak ring, journal entry.
- **`lib/screens/home_screen.dart`** — class `HomeScreen`. Legacy "exercise grid selection" page. Not in MainShell. Used during legacy entry-flow before the new tab system.

**Phase 7's "HomeScreen" refers to `dashboard_home_screen.dart`.** Confirming because the IDE has been showing the legacy `home_screen.dart` open repeatedly which is misleading.

### Color/size references in `dashboard_home_screen.dart`
- ~30 raw pixel literals for padding/sizing
- ~20 `VikaIvoryMain.X` direct color refs
- ~5 inline `TextStyle({fontFamily: …, fontSize: 13, fontWeight: FontWeight.w600, color: VikaIvoryMain.X})` blocks (most were converted to `GoogleFonts.beVietnamPro(textStyle: …)` in the previous turn)
- 0 `Theme.of(context)` references

After Phase 7 every pixel literal becomes `r.w(N)`, every color becomes `Theme.of(context).colorScheme.X` or a token-extension call, every TextStyle becomes `Theme.of(context).textTheme.X`.

---

## 8. Footguns

1. **VFTheme + VikaIvoryMain coexist.** Two theme systems. Long-term confusion. Phase 1 should explicitly mark legacy screens as "do not migrate yet, but route through new tokens for color literals when feasible". Eventually VFTheme retires.
2. **Bottom nav handles its own bottom inset.** `IvoryBottomNav` reads `MediaQuery.padding.bottom` directly. Any screen wrapped in `SafeArea(bottom: true)` would double-pad. Documented but easy to forget.
3. **Hardcoded touch target sizes** — `lib/widgets/plan/wordmark_header.dart` has `width: 38, height: 38` icon buttons, sub-spec for both iOS (44) and Android (48). Same in `lib/widgets/ivory/atoms.dart` (`AIDot` is 10–16px tap zone). Phase 5 fixes these via hit-test padding wraps.
4. **Status bar height never used as 47.** Good — that was a JSX prototype thing and didn't migrate.
5. **Hero card peek width is hardcoded** — `dashboard_home_screen.dart:120` uses `SizedBox(height: 470)` for the horizontal hero rail. On iPhone SE (375×667), 470px height eats more of the screen. On iPhone 15 Pro Max (430×932), 470px leaves more whitespace below. With responsive scaling this becomes `r.w(470)` ≈ 433 on SE, ≈ 510 on Pro Max. Better.
6. **Italic font availability** — `Be Vietnam Pro Italic` weights need to be bundled. Currently absent. Italic display will fall back to synthesised oblique = visually rough at 30–46pt. This was the root cause of the user's "italic doesn't look good" feedback two turns ago.
7. **`google_fonts` runtime fetch needs network on first launch.** If the app is opened offline first time, it falls back to system font and the user sees a wrong-looking screen until they go online. Bundling fixes this. Aligned with the prompt's intent.
8. **Reduced motion currently ignored.** Animations (PageView fade, AnimatedSize on dropdowns) run regardless of `MediaQuery.disableAnimations`. Phase 6.

---

## Open questions blocking Phase 1

1. **Display family decision** — Be Vietnam Pro single-family for display + body (my recommendation), or keep Oswald for display per current DESIGN.md? Phase 2's Typography spec lists Be Vietnam Pro only.
2. **`google_fonts` removal** — strict removal (option a, large refactor) or keep package + bundle .ttf (option b, quick migration)? My recommendation is (b).
3. **VFTheme.scale vs new Responsive** — replace and migrate the ~10 legacy callsites in this PR (recommended), or leave VFTheme.scale alongside and migrate later?
4. **Refactor scope of legacy screens** — in this PR we only refactor `dashboard_home_screen.dart`. But several legacy screens reference `VFTheme.scale` and `VFTheme.textStyle`. They'll keep working unchanged. Confirming this is OK.
5. **"design.md is the single source of truth, the code follows it"** — to satisfy this, after Phase 1 lands the dark tokens should be added to DESIGN.md FIRST, then implementation should mirror those values verbatim. I'll write the DESIGN.md update in Phase 1 alongside the code, both pointing at the same numbers — but if you want me to write DESIGN.md and pause for your review before writing the Dart constants, say so.

---

## Recommended Phase 1 plan (pending your approval)

1. Update DESIGN.md with: dark token block, spacing scale, radii scale, line-height rules, touch target rules, reference size, adaptive strategy. Single edit.
2. Bundle `BeVietnamPro-{Light,Regular,Medium,SemiBold,Bold,ExtraBold}.ttf` + italics into `assets/fonts/be_vietnam_pro/`. Declare in pubspec. Keep `google_fonts: ^6.2.1` in pubspec but switch the helper to `TextStyle(fontFamily: 'BeVietnamPro')`. Remove `Oswald` references unless you say keep.
3. Create `lib/theme/tokens/{colors_light,colors_dark,spacing,radii,elevation}.dart`. Each is a pure constants file.
4. Build `docs/contrast-report.md` from those tokens.
5. Stop. Get approval. Then Phase 2.

---

**Awaiting your call on the 5 open questions before any code lands.**
