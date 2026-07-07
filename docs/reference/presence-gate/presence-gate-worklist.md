# Presence-gate cleanup — shared worklist

Coordination sheet for the presence-gate cleanup pass (post-`PresenceGate` extraction).
Multiple agents edit this — **claim an item by writing your name in Owner, check the box when done,
don't edit the same file region as another open item at the same time.** Source of truth for the
decisions is Nam's review of `docs/reference/presence-gate/presence-pipeline-explained.html`.

Legend: 🔴 behavior fix · 🟡 behavior change (needs a call) · 🟢 safe cleanup · ❌ rejected/parked

## Decisions (resolved)
- ✅ **Confirm duration**: kept at **900ms**. Other agent standardized 900 across code + tests (gate tests green at 900).
- ✅ **manualPause guard**: removed. Verified resume is always reachable — `IvoryPauseOverlay` (with resume button) renders whenever `isPaused` is true, in any phase, so pausing pre-activation can't strand anyone.

## Work items

| # | Pri | Item | File:line | Change | Decision | Owner | Done |
|---|-----|------|-----------|--------|----------|-------|------|
| 1 | 🔴 | Confirm duration | `lib/exercise/presence_gate.dart:105` | Keep 900ms | Resolved → 900 (Nam). Other agent aligned code + tests. | other agent | [x] |
| 2 | 🟡 | Allow pause pre-activation | `lib/exercise/exercise_base.dart:187` | Removed the `exerciseState != activated` guard in `manualPause()` | Done. Resume reachable via pause overlay in any phase. | Claude | [x] |
| 3 | 🟢 | Doc/impl drift | `docs/canonical-numbers.md` (PresenceAnomalyDetector row) | `ANOMALY_DELTA` 0.20 → 0.15; also confirmed 60/10/3 match impl and dropped the "verify against impl" caveat | Done. | Claude | [x] |
| 4 | 🟢 | Edge-risk magic numbers | `lib/exercise/presence_gate.dart` (`_isPoseFrameEdgeRisk`) | Promoted `0.04 / ≥8 / ≥2 / ≥5` to `_FRAME_EDGE_*` consts. (Left the 0.25 visible-cutoff inline — not in the flagged set.) | Done. Behavior-preserving; gate tests green. | Claude | [x] |
| 5 | 🟢 | Drop debug line | `lib/exercise/exercise_base.dart:281` | Removed the `debugData['personStableMs']` if-block. `GateVerdict.personStableMs` kept (still tested). | Done. | Claude | [x] |
| 6 | 🟢 | Restore type signal | `lib/exercise/presence_gate.dart:290` | `runDetection([Object?])` → `([InputImage?])`. `InputImage` re-exported by the pose-detection import; no new import needed. | Done. Type-only. | Claude | [x] |
| 7 | ❌ | `_gatePhase` → exerciseState | `lib/exercise/exercise_base.dart:219` | (Do NOT collapse) | **Rejected.** Dependency boundary that keeps the gate free of an `exercise_base` import; collapsing re-creates the circular dep. | — | — |
| 8 | ❌ | Config provenance comments | `lib/utils/person_detector.dart:26` | (Skip) | **Can't do.** Original tuning date is lost; a fake "tuned on DATE" is worse than none. | — | — |
| 9 | ❌ | `_computeAvgPresence` weighting | `lib/exercise/presence_gate.dart` (`_computeAvgPresence`) | (Do NOT make side-aware) | **Rejected** (Fable confirmed 2026-07-06). Premise conflated presence with visibility: the average uses `presence` (0.988+ on occluded side-view joints, so no side-view drag); `visibility` is the noisy field and never enters it. Switching would *create* the misfires and silently re-baseline `PresenceAnomalyDetector` (same input). Full rationale: decisions.md 2026-07-06. | Fable | — |
| 10 | ❌ | `triggerCheck` per-reason limit | `lib/utils/person_detector.dart` | (Skip) | HUD-cosmetic only; not worth touching now. | — | — |

## Structural invariant — protect this
One-way flow with a **single** wire back (`verdict.personLostNow`). If any change starts reaching
from the gate into the base, or from the camera into the gate, stop — that property is what made the
timers testable. See §13 of the explainer HTML.
