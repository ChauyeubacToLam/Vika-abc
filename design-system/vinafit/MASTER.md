# Vinafit Design System — Master Reference

## Brand Identity

**Product**: AI-powered fitness coaching app with real-time pose detection
**Language**: Vietnamese (all user-facing strings)
**Platform**: Flutter (Android + iOS)
**Personality**: Premium, trustworthy, energetic but refined

---

## Dual-Theme Architecture

Vinafit uses **two distinct visual modes** by design:

| Context | Theme | Rationale |
|---------|-------|-----------|
| Dashboard, onboarding, settings | **Light** (warm premium) | Readability, trust, approachability |
| Camera, exercise, real-time coaching | **Dark** (high-contrast) | Reduce glare, focus on body overlay, gym-friendly |

---

## Color System

### Light Theme (Dashboard / Onboarding)

| Token | Hex | Usage |
|-------|-----|-------|
| `bg` | `#F7F8FA` | Main background (dashboard) |
| `bg` (onboarding) | `#F6F3EE` | Warm tan background |
| `bgDeep` | `#EDE9E3` | Deeper warm background |
| `surface` | `#FFFFFF` | Cards, panels |
| `accent` | `#2E856E` | Primary action (dashboard) |
| `accent` (onboarding) | `#0D7367` | Primary action (onboarding) |
| `accentBg` | `#E8F4EF` | Accent background fill |
| `accentText` | `#1D5C4A` | Accent-on-light text |
| `text` | `#111318` | Primary text |
| `textSec` | `#4B5563` | Secondary text |
| `textMuted` | `#9CA3B0` | Muted/caption text |
| `border` | `#0F000000` | 6% black border |

### Semantic Colors

| Token | Color | Background | Usage |
|-------|-------|------------|-------|
| `blue` | `#2563EB` | `#EEF4FF` | Info, active states |
| `amber` | `#D97706` | `#FEF9EC` | Warnings, caution |
| `coral` | `#E04A2F` | `#FAECE7` | Errors, bad form |
| `purple` | `#7C3AED` | `#F4F0FF` | Insights, AI features |
| `green` | `#2E856E` | `#EAF5F0` | Success, good form |
| `red` | `#DC3545` | — | Destructive actions |

### Dark Theme (Exercise / Camera)

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#080C1A` | Deep navy base |
| `primary` | `#00E5FF` | Cyan highlight |
| `secondary` | `#0091EA` | Blue accent |
| `surfaceDark` | `#0B1A1A` | Dark cards |
| `darkSurface` | `#111318` | Elevated dark surface |

### Gradient Patterns

- **Exercise cards**: 12% accent top → 6% secondary middle → dark bottom
- **CTA buttons**: `accent` solid with accent shadow (20% opacity, 22px blur)
- **Progress bars**: `accent` fill on `bgDeep` track

---

## Typography

### Font Family
**Roboto** — system default, excellent Vietnamese diacritics support

### Type Scale (responsive via `VFTheme.font()`)

| Style | Size | Weight | Spacing | Height | Usage |
|-------|------|--------|---------|--------|-------|
| `headerLarge` | 22px | w800 | -0.5 | 1.05 | Screen titles |
| `sectionTitle` | 16px | w700 | -0.3 | 1.1 | Section headers |
| `body` | 13px | w600 | — | 1.3 | Body text |
| `muted` | 11px | w500 | — | 1.3 | Captions, timestamps |
| `label` | 10px | w700 | 0.8 | — | ALL CAPS labels |

### Responsive Scaling
```
scale = (screenWidth / 390).clamp(0.92, 1.1)
fontSize = baseSize * scale
```

---

## Spacing & Layout

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| Screen padding | `width * 0.051` | Horizontal page margins |
| Section gap | `10 * scale` | Between sections |
| Card padding | 18px | Inner panel padding |
| Progress bar padding | 24px horizontal | Onboarding header |
| Button height | 54px | Full-width CTA |

### Corner Radii

| Element | Radius |
|---------|--------|
| Cards / Panels | `14 * scale` (≈14-15px) |
| Panels (onboarding) | 20px |
| Buttons | 16px |
| Small containers | `10 * scale` |
| Icon tiles | `12 * scale` |
| Pills / badges | 10px |
| Progress bars | 999px (full round) |

### Navigation

| Token | Value |
|-------|-------|
| Nav height | `(height * 0.084).clamp(64, 74)` |
| FAB size | `(width * 0.135).clamp(50, 58)` |
| Nav blur sigma | 18 |
| Nav surface opacity | 0.92 |

---

## Elevation & Shadows

| Level | Blur | Offset | Color | Usage |
|-------|------|--------|-------|-------|
| Card | 18px | (0, 8) | black 4% | Default card elevation |
| Accent | 22px | (0, 8) | accent 20% | CTA buttons, active cards |
| None | — | — | — | Flat elements, disabled states |

---

## Components

### VFButton
- Height: 54px, full-width
- Radius: 16px
- Active: `accent` fill + accent shadow
- Disabled: `bgDeep` fill, `textDim` text, no shadow
- Transition: 180ms AnimatedContainer

### VFPanel
- Surface card with 20px radius
- 18px padding, border + card shadow
- Optional color and border overrides

### VFPill / BadgePill
- 10px horizontal padding, 6px vertical
- 11px w700 text
- Color + background pair (semantic colors)

### VFProgressBar
- Back button (36x36, 12px radius) + brand text + step counter pill
- 4px LinearProgressIndicator with full-round clip

### VFCheckIcon
- Filled (accent bg + white check) or outline variant
- Custom painter for check mark

### AccentBarCard
- Left accent stripe (4px) with surface content

### StatCard
- Value + label with 12px vertical gap

### FrostedGlass
- BackdropFilter with configurable blur sigma
- Default: 18 sigma, 92% surface opacity

---

## Animation

### Timing

| Type | Duration | Curve |
|------|----------|-------|
| State transitions | 180ms | default |
| Container animations | 180–220ms | default |
| Card entry (staggered) | custom intervals | Curves.easeOut |
| Rep feedback banner | 2500ms | — |
| Micro-interactions | 150–300ms | ease |

### Patterns
- **Staggered entry**: Cards fade + slide in with offset intervals
- **AnimatedContainer**: For selection state changes
- **No overscroll glow**: Custom `VFScrollBehavior` with bouncing physics
- **No visible scrollbars**: Clean scroll experience

---

## Iconography

- **Material Icons** (built-in Flutter)
- **Cupertino Icons** (iOS-style, via `cupertino_icons` package)
- Consistent sizing within context
- No emoji as icons

---

## Accessibility

### Contrast Ratios
- Primary text (`#111318`) on light bg (`#F7F8FA`): **~16:1** (excellent)
- Secondary text (`#4B5563`) on light bg: **~7:1** (good)
- Muted text (`#9CA3B0`) on light bg: **~3.3:1** (decorative only)
- White text on accent (`#2E856E`): **~4.5:1** (meets AA)
- Cyan (`#00E5FF`) on dark (`#080C1A`): **~12:1** (excellent)

### Touch Targets
- Buttons: 54px height (exceeds 44px minimum)
- Back button: 36px (below 44px — consider increasing)
- Nav items: full tab width, nav height 64-74px

### Motion
- All animations < 300ms for micro-interactions
- Consider `MediaQuery.disableAnimations` for reduced motion

---

## File Reference

| File | Contains |
|------|----------|
| `lib/theme/vf_theme.dart` | Dashboard theme, scaling, glass effect |
| `lib/screens/onboarding/vf_theme.dart` | Onboarding theme, shared components |
| `lib/widgets/` | Reusable widget library |
| `lib/screens/main_shell.dart` | Navigation shell with bottom nav + FAB |

---

## Anti-Patterns to Avoid

1. **No gamification** — avoid static, boring exercise displays
2. **Don't mix themes** — light screens stay light, dark screens stay dark
3. **No emoji icons** — use Material/Cupertino icon sets
4. **Avoid layout shift** — reserve space for async content
5. **Don't skip scaling** — always use `VFTheme.scale()` for responsive sizing
6. **No raw hex in widgets** — use theme tokens from `VFTheme` / `VF`
