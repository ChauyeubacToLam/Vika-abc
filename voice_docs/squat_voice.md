# Squat Voice — Current Runtime Spec

**For:** dev team maintenance and future extension  
**Status:** synced to current code path in `Squat`, `SquatVoiceCoach`, and `ViettelTTSService`  
**Depends on:** `Squat` state machine, `ActiveExercisePage` wiring, `SquatVoiceCoach`, `ViettelTTSService`

---

## 1. What Exists Today

### ResultIssues (`lib/exercise/exercise_base.dart`)

```dart
class ResultIssues {
  Map<String, String> feedback = {};
  Map<String, Map<String, String>> instructions = {};
}
```

- `feedback{}` is per-frame and cleared every frame in the exercise runtime.
- `instructions{}` is phase-scoped coaching and can survive across frames until Squat overwrites or clears it.
- Squat voice reads this data. It does not recalculate pose landmarks for speech decisions.

### FaultRecord (`lib/exercise/fault_record.dart`)

```dart
class FaultRecord {
  final String phase;
  final String type;
  final String message;
  final bool affectsForm;
  final String? voiceMessage;
  final int priority; // lower = higher priority
}
```

- `voiceMessage` is the rep-end spoken candidate for that fault.
- `priority` is finalized upstream in Squat fault collection. Lower number means the cue is more important.

### Squat fault priority (`lib/exercise/squat/metrics/squat_metric_base.dart`)

```dart
class SquatFaultVoicePriority {
  static const int heelRise = 0;
  static const int trunkLean = 1;
  static const int depth = 2;
  static const int hipShoulderSync = 3;
  static const int tempo = 4;
  static const int trunkLeanBackward = 5;
}
```

This is the current source of truth for post-rep priority.

### Squat state machine (`lib/exercise/squat/squat.dart`)

```dart
enum SquatState { standing, descending, bottom, ascending }
```

What Squat already does today:

- `_updatePhaseInstructions()` writes the current `Status` instruction.
- `_completeRep()` increments `repCount`, collects faults, orders voiced faults, and stores:
  - `lastRepFaultVoiceMessages`
  - `lastRepTopVoiceMessage`
  - `lastRepTopVoicePriority`
  - `lastRepWasClean`
- `Squat.topVoicedFault(...)` and `Squat.orderedUniqueVoiceMessages(...)` centralize post-rep voice selection.

### Runtime voice wiring (`lib/screens/exercise/active_exercise_page.dart`)

This path is live:

- `ActiveExercisePage` creates `SquatVoiceCoach` when the exercise is a `Squat`
- `_processSquatVoiceFrame(...)` forwards runtime context into `coach.processFrame(...)`
- forwarding happens on pose and no-pose frames

### Playback stack (`lib/services/squat_voice_coach.dart` + `lib/services/viettel_tts_service.dart`)

What already exists:

- `SquatVoiceCoach`: gating, priority, cooldown, queue policy
- `ViettelTTSService`: singleton playback queue, local asset lookup, Viettel API fallback
- local asset playback is used when a phrase exists in `_assetMap`; otherwise the system falls back to Viettel TTS API

---

## 2. Current Runtime Path

```text
Camera frame
  -> ExerciseBase.processPose() / processNoPoseFrame()
  -> Squat.checkingPose()
  -> Squat._updatePhaseInstructions() / Squat._completeRep()
  -> ActiveExercisePage._processSquatVoiceFrame(...)
  -> SquatVoiceCoach.processFrame(...)
  -> ViettelTTSService.speak(...)
```

Key rules:

1. Metrics never call TTS directly.
2. The screen does not infer rep completion or fault priority on its own.
3. Voice only reads normalized exercise-layer data after Squat has already decided phase, faults, and rep completion.

---

## 3. Voice Layers in `SquatVoiceCoach`

### 3.1 Firing order inside `processFrame(...)`

| # | Layer | When | Source | Current behavior |
|---|---|---|---|---|
| 1 | Completion branch | `exerciseState == completed` | `exerciseState`, `repCount` | final rep count can be spoken first, then completion |
| 2 | Silent gate | not activated, paused, or no pose | `exerciseState`, `isPaused`, `hasPose` | no speech |
| 3 | Ready cue | first active frame only | `_didAnnounceReady == false` | `clearQueue()` then `Sẵn sàng` |
| 4 | Rep count | `repCount > _lastRepCount` | `repCount` | `clearPendingButKeepCurrent()`, speak count, then return |
| 5 | Post-rep feedback | same frame as rep increase | `lastRepWasClean`, `lastRepTopVoiceMessage` | enqueued after count if allowed |
| 6 | Phase cue | phase phrase changed | `instructions[currentPhase]['Status']` | spoken if gap allows and trunk live cue is not taking priority |
| 7 | Live fault cue | after phase evaluation | `feedback['Back']`, `feedback['Depth']` | trunk live cue can preempt queued phase speech |

### 3.2 Completed-set behavior

| Case | Behavior |
|---|---|
| Set just completed and rep also increased on that frame | clear pending queue, speak rep count, then speak `Hoàn thành bài tập` |
| Set completed on a later frame without new rep increase | clear pending queue once, then speak `Hoàn thành bài tập` |
| Completion already announced | no repeat |

### 3.3 Silent gates

No Squat voice should fire when:

1. `exerciseState != activated` and the exercise is not yet completed
2. `exercise.isPaused == true`
3. `hasPose == false`

Exception:

- completion logic still runs when `exerciseState == completed`

---

## 4. Phase Cue Behavior

Squat voice does not read raw enum names. It reads `Status` text written by Squat.

Current status writers in `Squat`:

| Phase | Status written by Squat |
|---|---|
| `standing` | `Xuống` |
| `descending` | `Going Down...` |
| `bottom` while hold remains | `Hold! {n}s` |
| `bottom` after hold completes | `Đứng lên` |
| `ascending` | `Đứng lên` |

Current mapping in `SquatVoiceCoach._phasePhraseFromStatus(...)`:

| Status text | Spoken phrase |
|---|---|
| starts with `Hold` or contains `Giữ` | `Giữ` |
| contains `Xuống` | `Xuống` |
| `Squat.isReleaseStatus(...)` or contains `Lên` | `Đứng lên` |
| contains `Đứng thẳng` | `Đứng thẳng` |
| `Going Down...` | no spoken phase cue |

Notes:

- `Going Down...` is intentionally silent. The anticipatory descent cue already comes from `standing -> Xuống`.
- Current squat flow does not actively emit `Đứng thẳng` as a phase cue anymore. Ascending now uses `Đứng lên`.
- On the very first active frame, after `Sẵn sàng`, the coach defers storing `Xuống` as the last phase phrase so the anticipatory descent cue can still play on the next standing frame.

---

## 5. Live Fault Voice

Current live-fault source is limited to `feedback`.

| Source | Condition | Spoken phrase | Cooldown |
|---|---|---|---|
| Back | `feedback['Back']` contains `Chest up` | `Ưỡn ngực lên` | 3000ms |
| Depth | `feedback['Depth']` contains `Go Lower` | `Thấp hơn nữa` | 3000ms |

Priority rules already implemented:

1. `Ưỡn ngực lên` is the highest-priority live fault cue.
2. If trunk live cue is eligible on the current frame, phase cue can be blocked for that frame.
3. When trunk cue fires, pending queue is cleared but the currently playing phrase is allowed to finish.

No other squat metrics currently produce live voice.

---

## 6. Post-Rep Voice

### 6.1 Current rep-end selection rule

Post-rep voice is decided upstream in `Squat._completeRep()`:

1. collect all metric faults for the completed rep
2. keep only faults with non-empty `voiceMessage`
3. sort by `priority`, then `type`, then `message`
4. store:
   - `lastRepFaultVoiceMessages`: ordered unique list of all rep-end voice messages
   - `lastRepTopVoiceMessage`: only the single top-priority phrase
   - `lastRepTopVoicePriority`
5. `SquatVoiceCoach` speaks only `lastRepTopVoiceMessage`

This means the current runtime rule is:

- only 1 post-rep instruction is spoken
- that instruction is the highest-priority voiced fault for the rep

### 6.2 Current post-rep fault-to-voice mapping

| Metric | `voiceMessage` | Priority | Spoken today |
|---|---|---|---|
| HeelRise | `Nhớ không nâng gót chân` | `0` | post-rep only |
| TrunkLean forward | none | `1` | live only |
| Depth | `Xuống thấp hơn` | `2` | live uses a different phrase, post-rep uses this phrase |
| HipShoulderSync | `Đừng nhấc hông lên trước` | `3` | post-rep only |
| Tempo | `Chậm lại` | `4` | post-rep only |
| TrunkLean backward | none | `5` | not spoken |

Important:

- `heel_rise` is the highest-priority post-rep cue.
- `hip_shoulder_sync` now has a post-rep cue.
- `tempo` still only speaks after the rep, never live.
- trunk backward lean still has no spoken phrase.

### 6.3 Post-rep gating in `SquatVoiceCoach`

Post-rep feedback is only enqueued when:

1. `exercise is Squat`
2. `lastRepWasClean == false`
3. `lastRepTopVoiceMessage` is not null or empty
4. the same post-rep phrase was not already used within the last 3 reps
5. the same phrase was not spoken live within the last 1500ms

---

## 7. Phrase Table Actually Used by Squat

### 7.1 Ready / phase / count / completion phrases

| Category | Phrase | Local asset in `_assetMap` |
|---|---|---|
| Ready | `Sẵn sàng` | Yes |
| Phase | `Xuống` | Yes |
| Phase | `Giữ` | Yes |
| Phase | `Đứng lên` | Yes |
| Rep count | `1` ... `30` | Yes |
| Completion | `Hoàn thành bài tập` | Yes |

### 7.2 Live and post-rep fault phrases

| Phrase | Used by current squat flow | Local asset in `_assetMap` |
|---|---|---|
| `Ưỡn ngực lên` | Yes | Yes |
| `Thấp hơn nữa` | Yes | Yes |
| `Xuống thấp hơn` | Yes | Yes |
| `Chậm lại` | Yes | Yes |
| `Nhớ không nâng gót chân` | Yes | Yes |
| `Đừng nhấc hông lên trước` | Yes | Yes |

Notes:

- If a phrase is missing from `_assetMap`, `ViettelTTSService` falls back to Viettel API.
- Squat now has local audio coverage for every phrase the current coach emits.

### 7.3 Legacy Squat Assets Removed

Removed legacy local phrases that the current squat runtime no longer emits:

- `Sẵn sàng, xuống`
- `Lên`
- `Tốt lắm`
- `Sai tư thế, chú ý`
- `Sẵn sàng, lên`

These phrases were previously cached locally but are no longer part of the active squat voice flow.

---

## 8. Data Contract Consumed by `SquatVoiceCoach`

### 8.1 Runtime API

```dart
void processFrame({
  required ExerciseBase exercise,
  required int repCount,
  required bool hasPose,
  required Map<String, String> feedback,
})
```

### 8.2 Data read on each frame

| Field | Purpose |
|---|---|
| `exercise.exerciseState` | activation and completion gate |
| `exercise.currentPhaseKey` | current phase lookup |
| `exercise.repCount` | rep count source of truth |
| `exercise.isPaused` | silence when paused |
| `hasPose` | silence when pose is missing |
| `exercise.resultIssues.instructions[currentPhaseKey]?['Status']` | phase cue source |
| `feedback['Depth']` | live depth cue source |
| `feedback['Back']` | live trunk cue source |

### 8.3 Rep-end data read by the coach

| Field | Purpose |
|---|---|
| `lastRepWasClean` | decides whether post-rep feedback is eligible |
| `lastRepTopVoiceMessage` | single post-rep spoken phrase |

### 8.4 Data already produced upstream but not fully consumed yet

| Field | Current state |
|---|---|
| `lastRepFaultVoiceMessages` | built upstream, not spoken sequentially |
| `lastRepTopVoicePriority` | stored upstream, coach does not read it directly |
| `setFeedback` | used for reporting/UI, not for live coach decisions |

---

## 9. Queue, Cooldown, and Priority Rules

### 9.1 Queue APIs currently used

| API | Current use |
|---|---|
| `clearQueue()` | start of session (`Sẵn sàng`), coach `dispose()` |
| `clearPendingButKeepCurrent()` | rep count, completion, trunk live cue |
| `speak(text)` | enqueue next phrase in order |

### 9.2 Cooldown constants already in code

| Rule | Value | Effect |
|---|---|---|
| Phase cue minimum gap | `250ms` | prevents rapid repeated phase speech |
| Same live fault phrase cooldown | `3000ms` | prevents live-fault spam |
| Same post-rep phrase cooldown | `3 reps` | prevents repeating the same correction every rep |
| Suppress post-rep if same phrase was just spoken live | `1500ms` | avoids live plus post-rep duplication back-to-back |

### 9.3 Priority rules already implemented

1. Completion branch wins over all other branches.
2. Rep count wins over phase and live-fault cues because `processFrame(...)` returns early after the rep branch.
3. `Ưỡn ngực lên` has the highest live-fault priority.
4. Post-rep priority is decided upstream by `SquatFaultVoicePriority`, with `heel_rise` highest.
5. Only one post-rep instruction is spoken.
6. When trunk live cue fires, pending queue is cleared but the current phrase is allowed to finish.

---

## 10. What Is Correct vs. Still Partial

### 10.1 Already correct in the current runtime

1. Squat voice is wired into `ActiveExercisePage`.
2. Ready, phase, live, rep, post-rep, and completion all exist in the same runtime path.
3. Rep-end speech is based on finalized rep data in `_completeRep()`, not guessed in UI.
4. Trunk cue already has highest live priority.
5. Heel rise now has the highest post-rep priority.
6. Hip-shoulder sync now has a post-rep cue.

### 10.2 Still partial

1. Only one post-rep phrase is spoken, even though `lastRepFaultVoiceMessages` stores the full ordered list.
2. Live speech still only covers `Depth` and `Back`.
3. `Nhớ không nâng gót chân` and `Đừng nhấc hông lên trước` do not have local audio assets yet and rely on API fallback.
4. There is still no squat-specific mute or per-exercise volume setting.

---

## 11. Safe Extension Rules

If squat voice is extended further, keep these rules:

1. Do not move TTS calls into metrics.
2. Do not teach the screen to infer rep completion or fault priority.
3. If multi-message post-rep feedback is added, consume `lastRepFaultVoiceMessages` instead of rebuilding the fault list from UI data.
4. If a new spoken phrase is added, update both the coach path and `_assetMap` if local cached audio is wanted.
5. Keep rep count and completion higher priority than phase and live-fault cues.

---

## 12. Testing Checklist

### Activation / ready

- [ ] `Sẵn sàng` fires exactly once after the exercise becomes `activated`
- [ ] no voice fires before activation completes

### Phase cues

- [ ] `standing` status `Xuống` can produce `Xuống`
- [ ] bottom hold status maps to `Giữ`
- [ ] bottom release status maps to `Đứng lên`
- [ ] ascending status maps to `Đứng lên`
- [ ] `Going Down...` does not produce spoken phase audio

### Live faults

- [ ] `feedback['Depth'] = Go Lower` produces `Thấp hơn nữa`
- [ ] `feedback['Back'] = Chest up!` produces `Ưỡn ngực lên`
- [ ] trunk cue wins over depth cue when both are present
- [ ] same live phrase does not repeat faster than every 3 seconds

### Rep-end flow

- [ ] every rep increase speaks the rep number once
- [ ] post-rep feedback only plays when `lastRepWasClean == false`
- [ ] post-rep feedback chooses exactly one phrase: `lastRepTopVoiceMessage`
- [ ] heel rise wins over all other post-rep voiced faults
- [ ] post-rep feedback is suppressed if the same phrase was already spoken live within 1.5 seconds
- [ ] same post-rep phrase does not repeat within 3 reps

### Completion

- [ ] final rep count can still be heard on the completion frame
- [ ] `Hoàn thành bài tập` fires once per set
- [ ] completion does not keep replaying on later frames

### Silent gates

- [ ] no voice while paused
- [ ] no voice while pose is missing
- [ ] no stale phase or live cue leaks after higher-priority rep or completion events

---

## 13. Bottom Line

The correct mental model for the current squat voice implementation is:

1. `Squat` generates business data.
2. `ActiveExercisePage` forwards runtime context.
3. `SquatVoiceCoach` decides priority, cooldown, and queue behavior.
4. `ViettelTTSService` plays local audio if available, otherwise falls back to Viettel API.

This file documents the current implementation. Further work should extend this path, not redesign it from scratch.
