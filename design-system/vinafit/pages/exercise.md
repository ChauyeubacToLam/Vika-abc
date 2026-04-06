# Exercise / Camera — Page Override

**Inherits from**: `MASTER.md` (all tokens apply unless overridden below)

## Theme Overrides

| Token | Master Value | Exercise Value | Reason |
|-------|-------------|----------------|--------|
| Theme mode | Light | **Dark** | Reduce glare, gym-friendly, focus on body overlay |
| `background` | `#F7F8FA` | `#080C1A` (deep navy) | Dark base for camera feed |
| `primary` | `#2E856E` | `#00E5FF` (cyan) | High-visibility accent on dark |
| `secondary` | `#2563EB` | `#0091EA` (blue) | Supporting accent |

## Visual Characteristics
- Full-screen camera feed as background
- Pose overlay drawn on camera preview
- Feedback banners animate in/out (2.5s)
- Exercise cards use gradient backgrounds (accent 12% → secondary 6% → dark)
- Staggered card entry animations

## Exercise Card Gradient
```dart
gradient: LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    accentColor.withOpacity(0.12),
    secondaryColor.withOpacity(0.06),
    darkBackground,
  ],
)
```

## Key Constraints
- Camera feed must not be obstructed by UI
- Feedback text must be readable over camera (use shadows/backdrop)
- Touch targets must be large enough for sweaty hands (56px+)
- Minimal UI during active exercise — only essential coaching info
