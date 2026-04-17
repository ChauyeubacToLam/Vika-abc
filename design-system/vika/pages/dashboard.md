# Dashboard — Page Override

**Inherits from**: `MASTER.md` (all tokens apply, no overrides needed)

## Theme Class
Use `VFTheme` (from `lib/theme/vf_theme.dart`).

## Layout Structure
- Bottom nav with frosted glass effect (blur 18, 92% opacity)
- 4 tabs + centered FAB for quick exercise start
- Content scrolls behind glass nav bar
- Safe area handling for notch/home indicator

## Navigation Shell
- `MainShell` wraps all dashboard tabs
- FAB opens exercise browser overlay
- Tab icons: Material Icons
- Active state: accent color
- Inactive state: textMuted

## Component Usage
- `StatCard` — Workout stats display
- `AccentBarCard` — Highlighted info cards
- `BadgePill` — Status/category tags
- `SectionHead` — Section title + optional action link
- `InsightCarousel` — Horizontal scrolling insight cards
- `GlowRing` — Decorative accent glow

## Scroll Behavior
- `VFScrollBehavior`: Bouncing physics, no scrollbar, no overscroll glow
- Content padding accounts for fixed nav height at bottom
