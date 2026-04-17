# Vika — Interface Design System

## Intent

**Who**: Vietnamese adults (20s-30s) training at home or small gyms without a personal trainer. Not technical. They want to feel guided, not monitored.

**What they do**: Pick exercises, get real-time form coaching via camera, track progress over time.

**Feel**: Like a high-end wellness brand — the confidence of a premium service that knows what it's doing. Not a neon gym. Not a clinical tool. Think: if a trusted coach had an app, it would feel like this. Calm authority.

**Keywords**: Trustworthy. Premium. Modern.

---

## Direction

### Personality
- **Trustworthy** = Consistency. Every element behaves predictably. Generous whitespace. No visual noise. Information hierarchy is effortless to scan.
- **Premium** = Restraint. Colors are muted and intentional. Surfaces feel material — subtle depth, warm tones. Nothing screams. Quality is in the details: precise spacing, smooth transitions, considered typography weights.
- **Modern** = Clean geometry. Rounded but not bubbly (14-20px radii). Flat with just enough shadow to imply structure. No gradients on surfaces — solid, confident fills.

### Color Philosophy
- **Teal-green** (`#0D7367` / `#2E856E`) as primary — health, growth, calm authority. Not the aggressive green of "go" — the deep green of a forest canopy. Trustworthy because it's not trying too hard.
- **Warm neutrals** (`#F6F3EE` bg, `#EDE9E3` deep) — paper-like warmth. Premium because it's not sterile white. Modern because warm neutrals signal contemporary design thinking.
- **Dark mode** (`#080C1A` + `#00E5FF` cyan) — reserved for exercise/camera. The shift to dark is a "focus mode" signal. Cyan highlights are precise, like a coach's annotation on your form.
- **Semantic colors** are soft-paired (color + light background) — never raw bright colors on white. This keeps alerts feeling integrated, not alarming.

### Depth Model
- **Level 0**: Background (`#F6F3EE`) — the canvas
- **Level 1**: Cards/panels (`#FFFFFF`, 4% black shadow at 18px blur) — content floats gently
- **Level 2**: Accent elements (accent shadow at 20% opacity, 22px blur) — CTAs and active states lift further
- **Level 3**: Overlays (frosted glass, blur 18, 92% opacity) — navigation, modals

No hard borders between levels. Transitions are atmospheric, not architectural.

### Typography Rules
- **Roboto** — chosen for Vietnamese diacritic quality, not just availability. At high weights (w700-w800) it carries athletic confidence without needing a display font.
- **Headers**: w800, tight letter-spacing (-0.5) — dense, authoritative
- **Body**: w600 at 13px — slightly heavier than typical body text, adds substance
- **Labels**: w700, 0.8 letter-spacing, ALL CAPS — structured, scannable
- **Scale**: Everything flows through `(width / 390).clamp(0.92, 1.1)` — the system breathes with the device

### Spacing Philosophy
- Proportional to screen width (`width * 0.051` margins)
- Tight section gaps (`10 * scale`) — premium density without crowding
- Generous card padding (18px) — content breathes inside containers
- The rhythm is: tight between related items, open between sections

### Motion
- **Fast**: 150-180ms for state changes (selections, toggles)
- **Medium**: 200-300ms for reveals and transitions
- **Deliberate**: No bounce, no overshoot. Ease-out curves. Premium motion is confident, not playful.
- **Staggered entry**: Cards arrive in sequence — implies order, care

### Signature Elements
1. **Dual-mode transition** — warm journal → dark studio. The personality shift IS the brand.
2. **Frosted glass navigation** — modern, premium, functional
3. **Accent shadow on CTAs** — teal glow beneath buttons signals "this is the action"
4. **Warm paper background** — distinguishes from every cold-white fitness app

---

## Token Reference

### Light Mode (Dashboard / Onboarding)
| Token | Value | Note |
|-------|-------|------|
| bg | `#F6F3EE` | Warm paper |
| bgDeep | `#EDE9E3` | Recessed areas |
| surface | `#FFFFFF` | Cards |
| accent | `#0D7367` | Primary action |
| accentSoft | `#E8F5F2` | Accent backgrounds |
| text | `#1A2B2B` | Primary text |
| textSec | `#4A6363` | Secondary text |
| textMuted | `#8FA3A3` | Captions |

### Dark Mode (Exercise / Camera)
| Token | Value | Note |
|-------|-------|------|
| bg | `#080C1A` | Deep navy |
| primary | `#00E5FF` | Cyan highlight |
| secondary | `#0091EA` | Blue accent |
| surface | `#0B1A1A` | Dark cards |

### Radii
| Element | Value |
|---------|-------|
| Cards | 14-20px |
| Buttons | 16px |
| Pills | 10px |
| Small | 10px |

### Shadows
| Level | Spec |
|-------|------|
| Card | `0 8px 18px rgba(0,0,0,0.04)` |
| Accent | `0 8px 22px rgba(accent,0.20)` |

---

## Anti-Patterns

- **No neon colors** — undermines trust
- **No bouncy animations** — undermines premium
- **No dense data tables** — this is a coach, not a spreadsheet
- **No raw white backgrounds** — always warm (`#F6F3EE` or `#F7F8FA`)
- **No emoji as UI elements** — use Material/Cupertino icons
- **No inconsistent radii** — every corner is deliberate
- **No color without its soft pair** — semantic colors always come as (foreground + background)
