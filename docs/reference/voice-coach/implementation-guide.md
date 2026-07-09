# Voice Coach — Implementation Guide (for Sonnet 5)

This is the build spec. The **design rationale** lives in `voice-coach-implementation.html`
(same folder) — read it once for the "why". This file is the "how", with every open
decision already made. Where a signature must match existing code, this guide names the
file to open — **read the real file and match it; do not invent signatures.**

Owner reviewed the design and locked the decisions below. Build in the staged order in §9;
each stage must leave `flutter analyze` and `flutter test` green.

---

## 0. Locked decisions (do not re-litigate)

| # | Decision | Answer |
|---|----------|--------|
| D1 | Event model | **Keep the adapter.** `PolicyVoiceCoach` diffs state on top of the existing `processFrame`. **Zero changes to the camera/exercise pipeline or `ExerciseBase`'s per-frame contract.** |
| — | Hunger keying | **Per-content for `correct`/`instruction`** (keyed by fault/metric id), per-type for `praise`/`count`/`hustle`. |
| — | Content model | **Flat catalog** `VoiceLib` + **modality bundles** `VoiceDefaults`, **both in one file** `voice_content.dart`. Scripts reference pools; nothing is retyped. |
| — | TTS | **Viettel removed entirely.** One asset sink. |
| — | Voice set | **Named, swappable, single set now** (`vika_v1`) behind a seam. Future voice = a name swap. Don't build multi-voice selection. |
| D8 | Praise ∝ quality | **In.** Cleaner rep → higher praise odds + bias toward the bigger praise line. |
| D2–D7 | numbers/naming/etc. | Ship the doc's recommended defaults; all live in one tuning table, tune on device. |

**Guardrail:** never touch the exercise pose/frame pipeline architecture. The whole point of
D1 is that this feature is additive.

---

## 1. Files (all new files under `lib/voice/`)

1. `voice_content.dart` — pure data: `CueType`, `CueContext`, `VoiceContent`, **`VoiceLib`** (pools),
   **`VoiceDefaults`** (bundles), `VoiceScript`. No I/O.
2. `voice_policy.dart` — `CueMode`, `CueTuning`, `kDefaultTuning`, **`VoicePolicy`** (pure brain).
3. `voice_sink.dart` — `VoiceSink` interface, `AssetVoiceSink` (wraps the one asset player),
   `VoiceSet` (the naming seam).
4. `voice_coach.dart` — `VoiceCoach` façade with `say()`.
5. `policy_voice_coach.dart` — `PolicyVoiceCoach` adapter implementing the existing coach contract.
6. `test/voice/voice_policy_test.dart` — policy unit tests (seeded `Random` + fake clock).

`VoiceScript` **evolves** today's `generic_exercise_voice_assets.dart` — fold that file's data
shape into `voice_content.dart` and delete the old file in stage 3.

---

## 2. Contracts to open first (read, then match — do NOT guess)

- **`ExerciseVoiceCoach`** interface + **`ExerciseBase.createVoiceCoach()`** — in `exercise_base.dart`.
  `PolicyVoiceCoach` must implement this interface exactly (same `processFrame(...)`,
  `waitUntilIdle`, `dispose`, whatever else it declares).
- **`QueuedAssetVoicePlayer`** public API — `AssetVoiceSink` wraps this; keep it, it's the one
  engine we keep.
- **`RepLog.data['fault_types']`** shape (`exercise_base.dart` ~L951) — already a structured list
  of fault ids; the adapter reads it. Confirm the exact type.
- **`ExerciseBase.ttsService`** field (`exercise_base.dart` ~L144) — this is deleted in stage 5.
- **`squat_voice_coach.dart`** — the phase-cue (`Xuống/Giữ/Đứng lên`, bottom-hold-release) and
  rep-outcome logic; preserve its behavior as `phaseCues` + a `VoiceScript` in stage 3.
- **`generic_exercise_voice_assets.dart`** — the `GenericExerciseVoiceScript` this replaces.

---

## 3. `voice_content.dart` — data layer

### CueType
```
enum CueType { count, praise, correct, instruction, hustle, phase, safety }
```

### CueContext — everything the pure brain is told (it stores nothing about exercise semantics)
```
class CueContext {
  final int repNumber;          // 1-based
  final bool isFinalReps;       // hustle eligibility (adapter decides from target)
  final bool clean;             // no fault this rep
  final double formScore;       // 0..1 rep quality — drives D8. 1.0 if unknown.
  final int faultPersistence;   // "how many reps has THIS fault been present" (adapter-computed)
  final String contentKey;      // the specific fault/metric id — hunger key for correct/instruction
  final bool sinkBusy;          // perishable cues drop if audio busy
}
```

### VoiceContent — what to say (resolution + randomness live in the coach, not here)
- `VoiceContent.key(String logicalKey)` — one key. If that key has variations registered in
  `VoiceLib.variations`, the coach picks one at random (no immediate repeat). This is note 6:
  "one key + variations, called with randomness."
- `VoiceContent.pool(List<String> logicalKeys)` — pick one at random (no immediate repeat).
- No `.tts(...)` factory. Viettel is gone.

### VoiceLib — the one place repetitive lines live (referenced, never retyped)
```
class VoiceLib {
  // Universal (modality-independent)
  static const praise    = ['common.good_1','common.good_2','common.good_3'];
  static const praiseBig = ['common.great_1','common.great_2'];        // standout reps (D8)
  // Rep-based family
  static const countReps  = ['common.count.1', /* … */ 'common.count.12'];
  static const hustleReps = ['common.one_more_rep','common.push'];
  // Time / hold family
  static const countTime  = ['common.time.30s','common.time.15s','common.time.5s'];
  static const hustleHold = ['common.hold_15s','common.keep_going'];
  // key -> variations, for VoiceContent.key auto-variation
  static const Map<String,List<String>> variations = { /* 'common.good': praise, ... */ };
}
```

### VoiceDefaults — modality bundles (SAME FILE, per owner's constraint)
```
class VoiceDefaults {
  static const repBased  = ScriptBundle(count: VoiceLib.countReps, hustle: VoiceLib.hustleReps, praise: VoiceLib.praise);
  static const timeBased = ScriptBundle(count: VoiceLib.countTime, hustle: VoiceLib.hustleHold, praise: VoiceLib.praise);
}
```

### VoiceScript — a per-exercise footprint = "which bundle + my faults"
```
class VoiceScript {
  final String slug;
  final List<String> faultIds;
  final List<String> praisePool, hustlePool, countPool;
  final Map<String,String> phaseCues;   // phaseKey -> logical key (squat/surya escape hatch)
  // Build from a bundle; override any pool by named arg.
  factory VoiceScript.from(ScriptBundle b, { required String slug, List<String> faultIds, ... });
  String faultKey(String id) => '$slug.$id';   // unchanged from today
}
// squat = VoiceScript.from(VoiceDefaults.repBased, slug:'squat', faultIds:['depth','valgus'], phaseCues:{...});
// plank = VoiceScript.from(VoiceDefaults.timeBased, slug:'plank', faultIds:['hips_sag','neck']);
```

---

## 4. `voice_policy.dart` — the brain (REVIEW/TEST THIS HARDEST)

Pure and deterministic given injected `Random` + clock. No I/O. This is where "not predictive"
is actually built.

```
enum CueMode { always, variableRatio, correction, base, perishable }
class CueTuning { final CueMode mode; final double base, step, cap; final int reliefAfter; ... }

const kDefaultTuning = {
  CueType.count:       CueTuning(CueMode.always,        ...),   // see §5 for the count rule
  CueType.praise:      CueTuning(CueMode.variableRatio, base:0.35, step:0.10, cap:0.85),
  CueType.correct:     CueTuning(CueMode.correction,    ...),   // 25→55→85 by persistence, reliefAfter:N
  CueType.instruction: CueTuning(CueMode.base,          ...),
  CueType.hustle:      CueTuning(CueMode.perishable,    base:0.50, cap:0.50),
  CueType.phase:       CueTuning(CueMode.perishable,    ...),
  CueType.safety:      CueTuning(CueMode.always,        ...),
};
```

### State (per set) + reset
```
final Map<String,int> _idle = {};   // hunger, keyed per-content (see _key)
int _lastPraiseRep = -1, _lastOutcomeRep = -1;
bool _hustledThisSet = false;
void beginSet() { _idle.clear(); _lastPraiseRep = _lastOutcomeRep = -1; _hustledThisSet = false; }
```

### The hunger key — the locked per-fault change (spell it out, it's the subtle part)
```
String _key(CueType type, CueContext ctx) =>
  (type == CueType.correct || type == CueType.instruction)
    ? '${type.name}:${ctx.contentKey}'   // per fault/metric — heel_rise ≠ raise_trunk
    : type.name;                         // praise/count/hustle collapse to the type
```
Consequence to protect in tests: staying silent on fault A must **not** raise the odds for fault B.

### decide() — the one entry
```
bool decide(CueType type, CueContext ctx) {
  final speak = _shouldSpeak(type, ctx);
  final k = _key(type, ctx);
  if (speak) { _onSpoke(type, ctx.repNumber, k); }      // reset hunger, stamp last-rep/outcome
  else       { _idle[k] = (_idle[k] ?? 0) + 1; }        // got hungrier
  return speak;
}
double _p(CueTuning t, int idle) => ((t.base + t.step*idle) * personality).clamp(0.0, t.cap);
```
`personality` (chattiness 0.5–1.5) multiplies **only** `base + step·idle`. It must **never**
touch `cap`, hard rules, or relief valves.

### Per-mode bodies (the lines to argue with — get the intent, tune the numbers on device)
- **praise** (`variableRatio`): refuse if `_lastPraiseRep == repNumber-1` (never twice in a row)
  or `_lastOutcomeRep == repNumber` (one outcome cue/rep); else roll `_p(t, idle)`.
  **D8:** scale the roll up with `ctx.formScore` and, when it fires, let the resolver bias toward
  `praiseBig` on high `formScore`. Owner wants to lean into praise — favour saying it.
- **correct** (`correction`): probability escalates with `ctx.faultPersistence` (≈25→55→85%);
  **relief valve:** if `faultPersistence >= t.reliefAfter`, return true (near-certain) — but respect
  one-outcome-cue/rep.
- **hustle** (`perishable`): `if (_hustledThisSet || _lastOutcomeRep == repNumber) return false;`
  only when `ctx.isFinalReps`; roll `_p`; on success set `_hustledThisSet = true`. ≤1/set.
- **phase** (`perishable`): drop if `ctx.sinkBusy`; otherwise roll.
- **count** (`always`): rep 1 always; middle reps ~70%, hunger +15/skip, **cap 0.90 — the roll must
  never reach certainty** (with cap 1.0 the step guaranteed a count after 2 skips: a learnable
  alternating rhythm, Nam 2026-07-08); **relief valve `reliefAfter: 6`** on the policy-internal
  idle streak — forces a count only after 6 straight silent counts, purely an uncounted-set guard.
  (Count is not an "outcome" cue — it may co-occur with a praise/correct.)
- **safety**: always, highest priority, bypasses hunger.

Helpers: `_onSpoke` resets `_idle[k]=0`, sets `_lastPraiseRep`/`_lastOutcomeRep` when the type is
praise/correct/hustle. `faultPersistence` is **not** tracked here — the adapter passes it in.

---

## 5. `voice_sink.dart` — audio + the voice-set seam

```
abstract class VoiceSink {
  bool get isBusy;
  Future<void> playKey(String logicalKey);   // resolves via active VoiceSet, then plays asset
  Future<void> waitUntilIdle();
  Future<void> stop();
  void dispose();
}
class VoiceSet { final String name; final String Function(String logicalKey) resolve; }   // one now: vika_v1
class AssetVoiceSink implements VoiceSink { /* wraps the single QueuedAssetVoicePlayer */ }
```
- `VoiceSet.vika_v1` maps logical keys (`'common.good_1'`) → asset paths under `assets/voice/…`.
  Swapping voices later = a different `VoiceSet`. Keep the indirection thin.
- **No Viettel.** If a logical key has no asset yet, `playKey` **no-ops safely** (debugPrint +
  skip) and records the key — never throw. See §8.

---

## 6. `voice_coach.dart` — the façade

```
class VoiceCoach {
  VoiceCoach({required VoiceSink sink, VoicePolicy? policy});
  void say(CueType type, VoiceContent content, CueContext ctx) {
    if (!_policy.decide(type, ctx)) return;         // brain decides if/when
    final key = _resolve(content);                  // pick variation, no immediate repeat
    _sink.playKey(key);                             // fire-and-forget
  }
  Future<void> waitUntilIdle(); void dispose(); void beginSet(); // delegates to policy/sink
}
```
Thin on purpose. All judgment is in the policy; all sound is in the sink. `_resolve` owns
randomness + no-immediate-repeat, and the D8 bias toward `praiseBig` when `ctx.formScore` is high.

---

## 7. `policy_voice_coach.dart` — the adapter (D1)

Implements the existing `ExerciseVoiceCoach` interface so the camera page is untouched. Holds the
prior-frame state and **diffs** it — this is the whole reason the pipeline doesn't change.

State kept between frames:
- `int _lastRepCount`
- `Map<String,int> _faultFirstSeenRep` (fault id → rep it first appeared) → yields `faultPersistence`
- last phase (for `phaseCues`)

On each `processFrame`:
1. **New set / activation** → `coach.beginSet()`, clear diff state.
2. **Rep landed** (`repCount` increased): read `RepLog.data['fault_types']`; build `CueContext`
   (repNumber, isFinalReps from target, clean = faults empty, formScore if the exercise exposes one).
   - `coach.say(count, VoiceContent.pool(script.countPool), ctx)`
   - if faults: for each fault id, compute persistence from `_faultFirstSeenRep`, then
     `coach.say(correct, VoiceContent.key(script.faultKey(id)), ctx.copyWith(contentKey:id, faultPersistence:p))`
   - else: `coach.say(praise, VoiceContent.pool(script.praisePool), ctx)`
   - if `isFinalReps`: `coach.say(hustle, VoiceContent.pool(script.hustlePool), ctx)`
3. **Phase change** (exercises with `phaseCues`, e.g. squat/surya): `coach.say(phase, VoiceContent.key(cue), ctx)`.
4. **Safety event** (if the exercise surfaces one): `coach.say(safety, …, ctx)`.

This one method replaces today's `_speakRepOutcome` / `_speakRepLogOutcome` /
`_enqueuePostRepFeedbackIfAllowed` across the 11 coaches.

---

## 8. Missing-audio checklist (owner requirement)

As you migrate, maintain `docs/reference/voice-coach/missing-audio.md`: every logical key that has
no recorded asset yet (surya pose/duration lines, time-based hustle, `praiseBig`, any new fault
line). Group by exercise. The sink's safe no-op (§5) means the app ships green while this list is
worked down. Hand this list back to the owner at the end of stage 4.

---

## 9. Migration — build in this order, each stage ships green

1. **Core, wired to nothing.** Files 1–5 + `voice_policy_test.dart`. `flutter analyze` + `flutter test` green. Nothing calls it yet.
2. **Switch the generic default.** Point `ExerciseBase.createVoiceCoach()` at `PolicyVoiceCoach` for the generic path. Verify generic exercises still speak (count/praise/correct).
3. **Migrate the 6 dedicated coaches + squat.** Delete each coach class; add its `VoiceScript`
   (`VoiceDefaults.repBased`/`timeBased` + faultIds, squat keeps `phaseCues`). Delete
   `generic_exercise_voice_assets.dart` once folded in.
4. **Surya.** Pre-record its fixed Sun-Salutation clips as assets; move it to `say(..., VoiceContent.key(...))`; drop its TTS path. Finalise `missing-audio.md`.
5. **Delete the dead.** Remove `ExerciseBase.ttsService`, `ViettelTtsService`, orphaned coach files, and the stale "5-layer voice priority queue" claim in `canonical-numbers.md`.

Owner will do stage-3/4 per-exercise review after stage 1–2 land, then act on the missing-audio list.

---

## 10. Tests (`voice_policy_test.dart`) — assert the behaviour, not the numbers

Seeded `Random` + injected clock. Cover:
- praise never twice in a row; only one of praise/correct/hustle per rep.
- hustle ≤1 per set and only when `isFinalReps`.
- correction probability rises with `faultPersistence`; relief valve fires past `reliefAfter`.
- **per-fault hunger independence:** many silent reps on fault A leave fault B's odds unchanged.
- personality scalar scales base+step but never exceeds `cap` and never overrides hard rules/valves.
- count: rep 1 always fires.
- re-running a set with the same seed reproduces the transcript; a different seed differs (the "same feel, different words" property).
