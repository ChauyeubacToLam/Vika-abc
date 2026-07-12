---
name: voice-copy
description: How to write Vietnamese voice-coach lines (audio strings) for Vika exercises — mandatory grounding steps, the cue formula, per-slot templates, register rules, data honesty. Use whenever writing or reviewing ANY voice line: metric faults, softs, reminders, setup intros, common-channel lines, or missing-audio.md entries.
---

# Writing Vika voice-coach lines

Every voice line is a string a Vietnamese user hears mid-exercise, usually unable to look at the
screen. This skill is the procedure + rules. It does NOT relitigate locked decisions (persona,
templates, routing — decisions.md 2026-07-10/07-11); it encodes them.

Owning docs (read these, don't duplicate them):
- Corpus + recording checklist: `docs/reference/voice-coach/missing-audio.md`
- Slot behavior (when lines fire): `docs/reference/voice-coach/voice-behavior-spec.md`
- Research basis (why these rules): `docs/reference/voice-coach/voice-research-rules.md` (§3d = wording)
- File naming: `docs/reference/voice-coach/audio-naming-convention.md`

## 0. MANDATORY grounding — never write a line for a metric you haven't read

Before writing any string for a metric fault/soft/reminder, in order:

1. **Read the exercise class** (`lib/exercise/<name>/<exercise>.dart`): what movement is this,
   what does a rep look like, what body position is the user in (lying? on all fours? can they
   see the screen?).
2. **Read the metric file** (`lib/exercise/<name>/metrics/<metric>.dart`): what does it actually
   measure — which landmarks, which threshold, what physically triggers the fault, and what user
   action clears it. The line must name THAT action, not a generic form tip for the exercise.
3. **Check the slot's behavior** in voice-behavior-spec.md (critical vs soft vs reminder fire
   differently; reminder has the tightest window).
4. **Check the existing corpus** in missing-audio.md — match its register, and never create a
   second wording for a fault that already has an approved one.

A line that describes something the metric doesn't measure is a data-honesty violation, the
hardest guardrail in the product. When the metric's mechanics are unclear from the code, stop and
ask — don't write a plausible-sounding line.

## 1. Persona + register (locked, decisions.md 07-10/07-11)

- Coach self-refers as **Vika**, addresses the user as **bạn**. (`bạn` over age-matched anh/chị is
  a conscious call — recorded-audio fleet size + unknown age/gender at runtime; see decisions.md
  07-11. Don't "fix" it.)
- Warm, encouraging, training-partner register. Never drill-sergeant, never scolding, never
  "you failed" framing.
- Corrections/suggestions end in **nhé** (softening particle). Never close a correction with bare
  **đi** or **nào** — blunt-command register.
- **Positive framing only**: state the target behavior. Never "đừng/không [X]" — negation primes
  the wrong image and names no replacement. ("Bạn giữ lưng thẳng nhé", never "Đừng cong lưng").
- User-facing = Vietnamese. Keys, files, docs = English.

## 2. The cue formula (the [action] inside every template)

**Verb + direction + concrete target.** Verb-first imperative, one idea per cue, as short as
possible while still specific.

Style: **external target by default** (attention on the movement's effect on the environment —
the strongest finding in cueing science), with a hard fence:

**NO-ASSUMPTION FENCE (Nam, 07-11): only universally-present targets.** The user is in an unknown
room. Allowed targets:
- **sàn / sàn nhà** (floor) — always there
- **trần nhà** (ceiling) — in-house users, always there
- **màn hình / điện thoại** (the phone/screen) — always there, it's filming them
- **the user's own body geometry** as a neutral shape ("thành một đường thẳng", "rộng bằng vai")

FORBIDDEN targets: tường (wall), ghế (chair), gương (mirror), thảm (mat), any furniture or room
feature that might not exist. "Đẩy hông về phía ghế" in a chair-less room is nonsense audio.

**Fallback ladder:** external cue with a safe target → anatomical cue (verb + body part +
direction) when no safe target exists. Never force a weird image to stay external; a clear
anatomical cue beats a confusing external one.

Examples:
- Glute bridge hip extension: ✅ "Bạn đẩy hông lên trần nhé." (verb đẩy + direction lên + target trần)
- Squat heel: ✅ "Bạn giữ gót chân chạm sàn nhé." (already external — floor)
- Push-up sag: ✅ "Bạn siết bụng, giữ thân thành một đường thẳng nhé." (no safe external target
  for the trunk → body-geometry shape)
- ❌ "Bạn lùi lại gần tường nhé." (wall assumption)
- ❌ "Bạn ngồi xuống như ngồi ghế nhé." (chair image — forbidden even as metaphor)
- ❌ "Đừng để hông chùng xuống." (negation, no target)

## 3. Per-slot templates and constraints

Routing rule (locked): **COMMON** (`common.*`, shared recording, hand-registered in
`GenericExerciseVoiceAssets.commonFiles`) = structural/channel lines about the camera/session.
**PER-EXERCISE** (`<slug>/<id>.mp3`, auto-resolved) = movement lines about this exercise's
mechanics. Metric audio stays per-exercise even when a metric class is reused.

| Slot | Routing | Template / shape | Constraints |
|---|---|---|---|
| Setup intro | per-exercise `<slug>.setup_position` | "Bạn [position instructions] nhé." | May be longer (fires pre-activation, once per set); orientation info belongs to common, not here |
| Setup/tracking guidance | common | Short state instruction ("Bạn quay nghiêng người với màn hình nhé.") | About camera/session only; register the key in commonFiles |
| Rep count | common | Bare numbers + final-2 forms | Not prose; don't touch without behavior-spec |
| Praise | common pool (rotating) | Short generic warmth ("Tốt lắm!", "Đẹp!") | GENERIC BY DESIGN — a shared recording can't name specifics. Per-metric specific praise is DEFERRED (decisions.md 07-11), don't sneak specifics in |
| Critical fault | per-exercise `<slug>/<fault_id>` | **"Bạn [action] nhé."** | Formula from §2; one fault, one action |
| Soft fault | `<fault_id>_soft` | **"Tốt, bạn [action] chút nữa là đẹp."** | Encouragement-paired correction; keep the Tốt opener |
| Reminder | `<fault_id>_reminder` | **"Lần này bạn nhớ [action] nhé."** | TIGHTEST slot: ~1.5s spoken, record brisk; forward instruction, never a diagnosis of the last rep |
| Hustle | common | Short imperative push ("Cố lên!", "Một cái nữa thôi!") | Warm training-partner, not drill-sergeant; ≤ a few words |
| Post-set | interpreter (text+voice) | Richest, most specific feedback | The ONLY place measured specifics belong: dominant fault + one fix for next set, drawn from actual fault counts |

Nam's verbatim wording wins over a mechanical template where he wrote one (existing corpus
precedent). New lines follow the template.

## 4. Data honesty in phrasing

- A line may only claim what the pipeline measured. Distinguish **instruction** (open-loop, always
  allowed: "Bạn thở ra khi nâng lên nhé" fired at a phase edge) from **feedback** (a claim about
  what the user did — allowed only if a metric measured it). Breathing, effort, "good breathing",
  "you're stronger today": instruction-phrasing only, never feedback-phrasing.
- Praise fires on measured-clean reps only; the words stay generic (see table).
- Reminders reference the fault by target action, not by accusation ("Lần này bạn nhớ giữ gót chân
  nhé", not a recap of the failure).

## 5. Delivery checklist (every new/changed line)

1. Grounding done (§0: exercise read, metric read, slot behavior checked, corpus checked).
2. Formula: verb-first, one idea, safe target or sanctioned anatomical fallback, positive framing.
3. Register: bạn + nhé, warm, no negation, no forbidden particles.
4. Length: fits its slot (~1.5–2s spoken; reminder strictest).
5. Honesty: nothing claimed that isn't measured; instruction vs feedback phrasing correct.
6. Routing + filename per audio-naming-convention.md; common keys registered.
7. Row added/updated in missing-audio.md (one-fact-one-place for wordings + recording status).
8. Read it aloud mentally in the user's physical position (lying down, mid-rep, can't see screen)
   — does it make sense with zero visual context?
