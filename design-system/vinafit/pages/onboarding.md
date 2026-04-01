# Onboarding — Page Override

**Inherits from**: `MASTER.md` (all tokens apply unless overridden below)

## Theme Overrides

| Token | Master Value | Onboarding Value | Reason |
|-------|-------------|------------------|--------|
| `bg` | `#F7F8FA` (cool gray) | `#F6F3EE` (warm tan) | Warmer, premium feel for first impression |
| `accent` | `#2E856E` | `#0D7367` | Slightly darker teal for better contrast on warm bg |
| `text` | `#111318` | `#1A2B2B` | Teal-tinted dark for cohesion |
| `textSec` | `#4B5563` | `#4A6363` | Teal-tinted secondary |
| `textMuted` | `#9CA3B0` | `#8FA3A3` | Teal-tinted muted |
| `border` | black 6% | `#EDE9E3` (bgDeep) | Warmer, subtler border |

## Theme Class
Use `VF` (from `lib/screens/onboarding/vf_theme.dart`), NOT `VFTheme`.

## Components Available
- `VFButton` — CTA with accent shadow
- `VFProgressBar` — Back + brand + step counter + progress
- `VFPanel` — Surface card (20px radius)
- `VFPill` — Semantic label pill
- `VFCheckIcon` — Filled or outline check
- `VFFitViewport` — Content scaling wrapper

## Layout Pattern
- 24px horizontal padding
- Content fills viewport via `VFFitViewport`
- Bottom CTA pinned with safe area spacing
- Page transitions: horizontal slide
