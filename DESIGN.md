---
version: alpha
name: Vika Premium Ivory
description: >
  Editorial coaching for Vietnamese urban professionals at home. Strength
  comes from voice and rhythm, not stadium aesthetics — a magazine you can
  trust holding your weekly habit.

colors:
  # Surfaces
  bg:               "#F4EEE2"   # cream — primary page surface
  bgRaised:         "#FBF7EE"   # raised cream cards
  bgInverse:        "#1F1812"   # warm-dark — never #000
  bgInverseHi:      "#2A1F12"   # warm-dark elevated
  powder:           "#EDE2CD"   # tinted cream for layered surfaces

  # Ink (warm, never pure black)
  ink:              "#1F1812"
  inkSoft:          "#5A4A3A"
  inkFaint:         "#8B7A66"
  inkGhost:         "#C9BBA6"

  # Inverse ink (cream on warm-dark)
  invInk:           "#F4EEE2"
  invInkSoft:       "#B0A990"   # ~72% of invInk
  invInkFaint:      "#7A715E"   # ~42% of invInk

  # Borders
  border:           "#E6DCC8"
  borderHi:         "#D4C8B0"

  # Yellow — RESERVED for stat / dot / underline / CTA only
  yellow:           "#FFB701"
  yellowInk:        "#1F1812"   # text on yellow

  # Status (used outside Plan)
  attention:        "#D67B3E"
  live:             "#22C55E"

typography:
  # Display family — Oswald. Condensed grotesque used widely in athletics
  # and sports brands. Strong, motivational, "strength coaching" voice.
  # Tracksmith and Whoop both lean on similar condensed-display systems.
  # Used at 18–80pt with optional italic for editorial moments.
  display-xl:
    fontFamily: Oswald
    fontSize: 80px
    fontWeight: 700
    lineHeight: 0.85
    letterSpacing: -2px

  display-lg:
    fontFamily: Oswald
    fontSize: 46px
    fontWeight: 700
    lineHeight: 0.92
    letterSpacing: -1.4px

  display-md:
    fontFamily: Oswald
    fontSize: 36px
    fontWeight: 700
    lineHeight: 0.95
    letterSpacing: -0.8px

  display-sm:
    fontFamily: Oswald
    fontSize: 26px
    fontWeight: 700
    lineHeight: 1
    letterSpacing: -0.6px

  display-xs:
    fontFamily: Oswald
    fontSize: 18px
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: -0.3px

  # Body family — Be Vietnam Pro. Workhorse for everything non-display.
  # Designed in Hanoi by Lâm Bảo specifically for Vietnamese diacritics —
  # "à ả ã á ạ" render with proper stacking, not afterthought.
  body-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 16px
    fontWeight: 500
    lineHeight: 1.45

  body-md:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: 500
    lineHeight: 1.45

  body-sm:
    fontFamily: Be Vietnam Pro
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.5

  # Labels — small uppercase tracked. The "section mark" voice.
  label-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 13px
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: 0.16em

  label-md:
    fontFamily: Be Vietnam Pro
    fontSize: 10px
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: 0.20em

  label-sm:
    fontFamily: Be Vietnam Pro
    fontSize: 9px
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: 0.18em

  # Numerals — tabular for stats. Be Vietnam Pro at heavier weight.
  numeral-display:
    fontFamily: Be Vietnam Pro
    fontSize: 30px
    fontWeight: 800
    lineHeight: 0.9
    letterSpacing: -0.04em
    fontFeature: '"tnum"'

  numeral-md:
    fontFamily: Be Vietnam Pro
    fontSize: 16px
    fontWeight: 800
    letterSpacing: -0.02em
    fontFeature: '"tnum"'

  numeral-sm:
    fontFamily: Be Vietnam Pro
    fontSize: 11px
    fontWeight: 700
    letterSpacing: 0.01em
    fontFeature: '"tnum"'

rounded:
  xs: 6px
  sm: 10px
  md: 14px
  lg: 18px
  xl: 22px
  xxl: 28px
  pill: 999px

spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 22px
  xxl: 28px
  page: 24px        # default horizontal page padding
  hero: 22px        # internal padding for hero cards

components:
  card-cream:
    backgroundColor: "{colors.bgRaised}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xl}"
    textColor: "{colors.ink}"

  card-warm-dark:
    backgroundColor: "{colors.bgInverse}"
    rounded: "{rounded.xxl}"
    padding: "{spacing.xl}"
    textColor: "{colors.invInk}"

  pill-cta-primary:
    backgroundColor: "{colors.yellow}"
    textColor: "{colors.yellowInk}"
    rounded: "{rounded.pill}"
    typography: "{typography.body-md}"

  pill-cta-on-dark:
    backgroundColor: "{colors.bg}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    typography: "{typography.body-md}"

  section-mark-bar:
    backgroundColor: "{colors.yellow}"
    width: 4px
    height: 22px

  divider-hairline:
    backgroundColor: "{colors.border}"
    height: 1px

  # Eyebrow as a component to standardize the pattern across screens.
  eyebrow:
    typography: "{typography.label-md}"
    textColor: "{colors.inkFaint}"

  eyebrow-on-dark:
    typography: "{typography.label-md}"
    textColor: "{colors.invInkFaint}"

  eyebrow-yellow:
    typography: "{typography.label-md}"
    textColor: "{colors.yellow}"
---

# Vika Premium Ivory

## Overview

Vika is an AI-powered home fitness app for Vietnamese urban professionals.
The visual identity is **editorial coaching**: a magazine you can trust
holding your weekly habit. Strength shows through voice and rhythm, not
stadium aesthetics. Everything is warm, considered, deliberate. No pure
black, no neon greens, no chest-thumping. The user is treated like a
reader of a serious publication, not a "user".

The signature device is **italic Fraunces at display sizes**. It carries
the editorial tone — like a magazine pull-quote in the middle of a serious
weekly routine. Outside of these moments, **Be Vietnam Pro** does the
quiet workhorse job: stat numerals, body text, labels, captions. Be
Vietnam Pro was designed in Hanoi specifically for the language; its
diacritic stacks (à ả ã á ạ) are tighter and more elegant than any
international sans.

The palette is warm ivory cream with warm-dark accents. **Yellow is
reserved**: it appears only as (1) a stat number, (2) a dot indicator,
(3) an underline accent, or (4) a CTA. Anything else demanding the user's
attention has to earn it some other way.

## Colors

The palette is rooted in a single warm-ivory cream and a warm-dark
counterpart. There is exactly one accent.

- **bg `#F4EEE2`** — Cream foundation, the page surface. Warmer and
  softer than off-white. Inspired by uncoated book stock.
- **bgRaised `#FBF7EE`** — A whisper lighter than cream. Used for raised
  cards on a cream background — the elevation cue is *warmth*, not *shadow*.
- **bgInverse `#1F1812`** — Warm-dark. Pure black is forbidden. Hero
  cards on Home / Plan / Progress sit on this surface, with cream type
  layered over.
- **ink `#1F1812`** — Primary text on cream. Same hex as bgInverse —
  inverted relationship between surface and ink.
- **inkSoft / inkFaint / inkGhost** — Three opacities of warm-dark for
  hierarchy.
- **yellow `#FFB701`** — The single accent. Reserved for stat / dot /
  underline / CTA. Fitness amber: warmer than canary, more matte than
  taxi yellow. Used sparingly so it stays meaningful.
- **attention `#D67B3E`** — Warm orange for "needs improvement" form
  scores. Never red — Vika doesn't punish.
- **live `#22C55E`** — A live recording indicator (recording sessions).
  Used only inside the camera screen.

### Forbidden

- Pure black (`#000000`)
- Pure white (`#FFFFFF`) on cream surfaces
- Cool grays — all neutrals must be warm
- Red as a status color — use `attention` orange instead

## Typography

Vika uses two families. The pairing is deliberate.

### Oswald — display headlines, motivational voice

Oswald is a condensed grotesque widely used in athletics, sports
journalism, and fitness brands. At 30–80pt with weight 700–800 it carries
the **strength-coaching voice** that defines Vika: **TUẦN 03**, **KHOẺ
HƠN RÕ RỆT**, **ĐẨY MẠNH**. The condensed proportions feel athletic and
punchy without being gimmicky.

Oswald supports italic at all weights. Italic display moments retain
the editorial-coach feel without losing strength — *Toàn thân nhẹ*,
*Đẩy mạnh.* Vietnamese diacritics render correctly thanks to extensive
Latin Extended Additional support.

**Use Oswald for:**
- Page hero ("Tuần 03", "Khoẻ hơn rõ rệt.")
- Hero card titles ("Toàn thân nhẹ", "Đẩy mạnh.")
- Stat values on lifetime hero (`8` buổi, `74` %)
- Coach-voice quotes (italic Oswald, body sizes)
- Italic editorial accents in eyebrows and quotes

**Don't use Oswald for:**
- Body text — too condensed for paragraph reading
- Eyebrows / labels — caps in Oswald look fine but stats need Be Vietnam Pro's tabular figures
- Numerals in dense charts — Be Vietnam Pro's `tnum` aligns columns better

### Be Vietnam Pro — body & labels

Be Vietnam Pro is the workhorse. Designed in Hanoi by Lâm Bảo specifically
for Vietnamese, it has:
- Tighter diacritic stacks than international sans
- Optical sizing that reads cleanly at 9pt eyebrow scale
- A no-nonsense character that complements Fraunces' literary tone

**Use Be Vietnam Pro for:**
- All body copy, captions, supporting text
- Section mark labels, eyebrow micro-text
- Stat unit suffixes (`buổi`, `%`, `phút`)
- Tabular numerals in charts (with `fontFeature: '"tnum"'`)
- Vietnamese weekday letters (T2 / T3 / T4...)

### Italic synthesis fallback

If italic .ttf files aren't bundled, the Fraunces italic look is lost
and Flutter synthesises oblique by skewing the upright weight. The bundle
**must** include the italic variants for both families. Without them, the
visual identity collapses.

## Layout

### Page rhythm

Each main-app screen follows a consistent rhythm:

1. **Wordmark header** at top (always pinned)
2. **§01 Section mark** — yellow vertical bar, label, hairline, "01 / 02"
   index numeral. Establishes which "chapter" of the page you're reading.
3. **Editorial header** — italic Fraunces display + cumulative meta line
   in Be Vietnam Pro
4. **Content** — broken into §02, §03, etc.
5. **Editorial closer** — bottom hairline, "VIKA · TAB_NAME" wordmark,
   italic tagline. The "back of the book" feel.

This rhythm IS the publication. Skipping pieces breaks the metaphor.

### Spacing scale

Vika uses an 8px base scale — but page padding is 24px (the magazine
"gutter"), and hero cards have 22px internal padding (slightly tighter
than page gutter, to feel "set in" the layout).

### Hero card sizing

- **Warm-dark heroes** (Today's workout, Lifetime stats, Headline
  metric) use `rounded.xxl` (28px) — generous radius reads as
  importance.
- **Cream supporting cards** use `rounded.xl` (22px).
- **Inline elements** (filters, stats, list rows) use `rounded.md` (14px)
  or `rounded.sm` (10px).

## Elevation & Depth

Vika does not use drop shadows for elevation. Elevation cues are:

1. **Warmth shift** — bgRaised on bg, or bgInverseHi on bgInverse
2. **Hairline borders** — 1px in `border` color
3. **Internal padding** — generous interior space signals importance

Two exceptions where shadow IS used:
- **Yellow CTA pills** — `0 8px 22px rgba(255,183,1,0.35)` so they
  visually float
- **Bottom nav capsule** — `0 8px 28px rgba(31,24,18,0.10)` so it
  reads as floating glass

Both are restrained. Most surfaces are flat.

### Yellow radial wash

Several warm-dark hero cards (Plan TodayCard, Progress HeadlineHero,
Profile LifetimeHero, Library AISpotlight) have a **yellow radial
gradient wash** in the top-right corner. This is the "publication
masthead light" — a soft glow that reads as warmth, not interaction.

```
Wash specs:
  position: top: -50, right: -50  (anchored off-canvas)
  size: 200×200 circle
  gradient: radial, yellow @ 0.18 opacity → transparent
  stops: [0, 0.65]
```

It must be subtle. If you can clearly *see* the yellow, it's too strong.

## Shapes

Cards are heavily rounded (22–28px radius). Pills and buttons are
fully rounded (`rounded.pill = 999px`). Small inline elements stay at
10–14px.

The yellow vertical bar at section marks is `4×22px` with `2px` radius
— specifically NOT a pill. Reads as a printed accent, like a colored
margin rule in a magazine.

The warm-dark FigureSkeleton on TodayCard is wireframe — yellow joint
dots, faint outline. Represents AI pose tracking, not a body
silhouette. Do not "fill it in" — the wireframe IS the content.

## Components

### Wordmark header
Yellow accent bar (4×28px) + italic "vika" wordmark in Fraunces 800
italic at 32pt + trailing icon button (calendar, bell) + circular avatar.

### Section mark
`§01 · CHAPTER NAME · ─── · 01 / 02`

Yellow bar 4×22px, then label-lg in inkFaint, hairline divider,
optional "01 / 02" tabular numeral on the right.

### Editorial closer
`VIKA · LỘ TRÌNH · ─── · italic tagline.`

Bottom hairline, label-md `VIKA · SECTION` in inkFaint with tabular
numerals, hairline, italic body-sm tagline. Always at the bottom of
each page or scroll context.

### Coach mark + quote
The "huấn luyện viên ghi" voice. Always paired:

1. CoachMark glyph (yellow disc, ink stick figure inside, 14px or 18px)
2. Eyebrow `HUẤN LUYỆN VIÊN GHI`
3. Italic Fraunces body-md quote

This is the most important component. It's how Vika feels human.

### Hero day card (current)
Warm-dark surface, italic Fraunces title (1–2 lines), 4-stat tile grid,
yellow CTA pill. Optional FigureSkeleton overlay (Today only on Home).

### Yellow CTA pill
Yellow background, ink text, right-side circular ink "knob" with yellow
arrow. Inverse on warm-dark surfaces (cream pill with ink knob and
yellow arrow). Always full-width inside cards.

### AI dot
Yellow filled dot (10px or 12px) with thin outer ring at 50% opacity.
Indicates "this exercise has camera AI form analysis". Replaces the
louder "AI FORM" tag pattern from earlier prototypes.

## Do's and Don'ts

### Do
- ✓ Use italic Fraunces at display sizes for editorial moments
- ✓ Use Be Vietnam Pro tabular figures for any column of stat numbers
- ✓ Reserve yellow for stat / dot / underline / CTA
- ✓ Pair CoachMark with `HUẤN LUYỆN VIÊN GHI` eyebrow + italic quote
- ✓ Use warmth shift (bgRaised vs bg) for elevation, not shadow
- ✓ Cap pure white at zero — surfaces are cream all the way down

### Don't
- ✗ Use pure black (#000) anywhere — substitute warm-dark #1F1812
- ✗ Apply yellow to backgrounds, large surfaces, or as a shadow color
- ✗ Use Fraunces in upright form — Fraunces lives in italic in Vika
- ✗ Use Be Vietnam Pro for display — it's a sans, not editorial
- ✗ Synthesise italic from upright weights — bundle the italic .ttf files
- ✗ Use red as an "attention" color — use `attention` orange instead

## Asset requirements

**Fonts**: Loaded at runtime via the `google_fonts` package (already a
Vika dependency). No manual `.ttf` bundling needed. First launch fetches
from Google Fonts CDN; subsequent launches use the on-device cache.

- https://fonts.google.com/specimen/Oswald
- https://fonts.google.com/specimen/Be+Vietnam+Pro

If full offline-first is desired later, drop `.ttf` files into
`assets/fonts/` and re-add the `flutter > fonts` declarations in
`pubspec.yaml`. The `google_fonts` package will use the bundled files
automatically.

**Body silhouette PNGs** for the Progress heatmap:
- `assets/images/body_male.png`
- `assets/images/body_female.png`
