# Squat Voice — Implementation Spec

**For:** Dev team maintenance and future extension  
**Status:** Running on the current runtime path  
**Depends on:** `Squat` state machine, `ActiveExercisePage` wiring, `SquatVoiceCoach`, `ViettelTTSService`

---

## 1. What Exists Today (Do NOT Delete)

### ResultIssues (`lib/exercise/exercise_base.dart`)
```dart
class ResultIssues {
  Map<String, String> feedback = {};
  Map<String, Map<String, String>> instructions = {};
}
```

- `feedback{}`: per-frame, cleared every frame in `processPose()` and `processNoPoseFrame()`.
- `instructions{}`: phase-scoped coaching, survives across frames until Squat clears it on the next rep start.
- Squat voice reads from this same data. It does not recalculate landmarks for speech decisions.

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

- `voiceMessage` is the rep-end phrase candidate.
- `priority` is already used in `Squat._completeRep()` to sort voiced faults and choose the top message for the completed rep.

### Translation / UI layer (`lib/screens/exercise/active_exercise_page.dart`)

Existing helpers:

- `_translateFeedbackValue(key, value)`
- `_translateInstruction(value)`
- `_translateStatus(value)`
- `_translateResult(value)`

These stay.

Squat voice does **not** speak those translated UI sentences directly. It reads the same upstream `feedback` and `instructions`, then maps them into short canonical speech phrases.

### Squat state machine (`lib/exercise/squat/squat.dart`)
```dart
enum SquatState { standing, descending, bottom, ascending }
```

What already exists:

- `_updatePhaseInstructions()` writes business-facing `Status` text for the current phase.
- `_completeRep()` increments `repCount`, collects faults, sorts voiced faults by `priority`, and stores:
  - `lastRepFaultVoiceMessages`
  - `lastRepTopVoiceMessage`
  - `lastRepTopVoicePriority`
  - `lastRepWasClean`

### Runtime voice wiring (`lib/screens/exercise/active_exercise_page.dart`)

This path is already live in runtime:

- `ActiveExercisePage` creates `SquatVoiceCoach` when `widget.exercise is Squat`
- `_processSquatVoiceFrame(...)` forwards frame context into `coach.processFrame(...)`
- forwarding happens on both:
  - pose frames via `processPose(...)`
  - no-pose frames via `processNoPoseFrame()`

This means Squat voice is already wired into the exercise screen. It is not a dormant helper.

### Playback stack (`lib/services/squat_voice_coach.dart` + `lib/services/viettel_tts_service.dart`)

What already exists:

- `SquatVoiceCoach`: gating, priority, cooldown, queue policy
- `ViettelTTSService`: singleton playback queue, local asset lookup, Viettel API fallback
- `_voiceController` indicator UI also exists on the screen, but unlike the original system-wide proposal, Squat now has actual audio playback behind it

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

Key rules of the current path:

1. Metrics never call TTS directly.
2. The screen does not infer rep completion on its own.
3. Voice only reads normalized business data after the exercise layer has already decided phase, faults, and rep completion.

---

## 3. Current Squat Voice Layers

### 3.1 Firing order inside `SquatVoiceCoach.processFrame(...)`

| # | Layer | When | Source | Current behavior |
|---|---|---|---|---|
| 1 | Completion branch | `exerciseState == completed` | `exerciseState`, `repCount` | Final rep count can be spoken first, then completion |
| 2 | Silent gate | not activated, paused, or no pose | `exerciseState`, `isPaused`, `hasPose` | No speech |
| 3 | Ready cue | first active frame only | `_didAnnounceReady == false` | `clearQueue()` then `Sẵn sàng` |
| 4 | Rep count | `repCount > _lastRepCount` | `repCount` | `clearPendingButKeepCurrent()`, speak count, then return |
| 5 | Post-rep feedback | same frame as rep increase | `lastRepWasClean`, `lastRepTopVoiceMessage` | Enqueued after count if allowed |
| 6 | Phase cue | phase/status changed | `instructions[currentPhase]['Status']` | Spoken if gap allows and trunk cue is not taking priority |
| 7 | Live fault cue | after phase evaluation | `feedback['Back']`, `feedback['Depth']` | Trunk cue has highest live priority |

### 3.2 Completed-set behavior

| Case | Behavior |
|---|---|
| Set just completed and rep also increased on that frame | clear pending queue, speak rep count, then speak `Hoàn thành bài tập` |
| Set completed on a later frame without new rep increase | clear pending queue once, then speak `Hoàn thành bài tập` |
| Completion already announced | no repeat |

### 3.3 Phase cue behavior

Squat voice does not read raw enum names. It reads `Status` text written by Squat.

Current mapping:

| Status text | Spoken phrase |
|---|---|
| contains `Xuống` | `Xuống` |
| starts with `Hold` or contains `Giữ` | `Giữ` |
| contains `Đứng lên` or `Lên` | `Đứng lên` |
| contains `Đứng thẳng` | `Đứng thẳng` |
| `Going Down...` | no phase voice |

`Going Down...` not being voiced is intentional. The anticipatory descent cue already comes from `standing -> Xuống`.

---

## 4. Phrase Table Actually Used by Squat

### 4.1 Ready / phase / rep / completion phrases

| Category | Phrase | Asset exists in `_assetMap` |
|---|---|---|
| Ready | `Sẵn sàng` | Yes |
| Phase | `Xuống` | Yes |
| Phase | `Giữ` | Yes |
| Phase | `Đứng lên` | Yes |
| Phase | `Đứng thẳng` | Yes |
| Rep count | `1` ... `30` | Yes |
| Completion | `Hoàn thành bài tập` | Yes |

### 4.2 Fault-to-voice mapping currently implemented

| Metric / source | Live source | Live phrase | Rep-end `voiceMessage` | Priority | Current usage |
|---|---|---|---|---|---|
| Depth | `feedback['Depth'] == 'Go Lower'` | `Thấp hơn nữa` | `Xuống thấp hơn` | 1 | live + post-rep |
| TrunkLean forward | `feedback['Back'] == 'Chest up!'` | `Ưỡn ngực lên` | `Ưỡn ngực lên` | 0 | live + post-rep |
| Tempo | none | none | `Chậm lại` | 2 | post-rep only |
| HeelRise | none | none | none | n/a | no voice |
| HipShoulderSync | none | none | none | n/a | no voice |

Notes:

- `TrunkLean` backward fault has no `voiceMessage`, so it is not spoken post-rep.
- `Feet`, `Tempo`, and `Sync` can still appear in UI feedback or instruction data without producing live speech.

### 4.3 Assets present in TTS but not used by current Squat coach

Examples:

- `Sẵn sàng, xuống`
- `Lên`
- `Tốt lắm`
- `Sai tư thế, chú ý`
- `Sẵn sàng, lên`

These asset keys exist in `_assetMap`, but `SquatVoiceCoach` does not call them in the current flow.

---

## 5. Data Contract Consumed by `SquatVoiceCoach`

### 5.1 Current runtime API
```dart
void processFrame({
  required ExerciseBase exercise,
  required int repCount,
  required bool hasPose,
  required Map<String, String> feedback,
})
```

### 5.2 Data read directly on each frame

| Field | Purpose |
|---|---|
| `exercise.exerciseState` | gate for activation / completion |
| `exercise.currentPhaseKey` | track phase change |
| `exercise.repCount` | source of truth for rep counting |
| `exercise.isPaused` | silence when user leaves the frame long enough |
| `hasPose` | silence when current frame has no pose |
| `exercise.resultIssues.instructions[currentPhaseKey]?['Status']` | phase cue source |
| `feedback['Depth']` | live depth cue source |
| `feedback['Back']` | live trunk cue source |

### 5.3 Rep-end data read by the coach

| Field | Purpose |
|---|---|
| `lastRepWasClean` | decides whether post-rep feedback is eligible |
| `lastRepTopVoiceMessage` | single post-rep phrase candidate |

### 5.4 Data already produced upstream but not fully consumed yet

| Field | Current state |
|---|---|
| `lastRepFaultVoiceMessages` | built upstream, not spoken sequentially |
| `lastRepTopVoicePriority` | stored upstream, coach does not read it directly |
| `setFeedback` | used for reporting/UI, not for live coach decisions |

---

## 6. Queue, Cooldown, and Priority Rules

### 6.1 Queue APIs currently used

| API | Current use |
|---|---|
| `clearQueue()` | start of session (`Sẵn sàng`), coach `dispose()` |
| `clearPendingButKeepCurrent()` | rep count, completion, trunk live cue |
| `speak(text)` | enqueue next phrase in order |

### 6.2 Cooldown constants already in code

| Rule | Value | Effect |
|---|---|---|
| Phase cue minimum gap | `250ms` | prevents rapid repeated phase speech |
| Same live fault phrase cooldown | `3000ms` | prevents live-fault spam |
| Same post-rep phrase cooldown | `3 reps` | prevents repeating the same correction every rep |
| Suppress post-rep if same phrase was just spoken live | `1500ms` | avoids live + post-rep duplication back-to-back |

### 6.3 Priority rules already implemented

1. Completion branch wins over all other branches.
2. Rep count wins over phase and live-fault cues because `processFrame(...)` returns early after the rep branch.
3. Trunk live cue (`Ưỡn ngực lên`) has higher priority than depth live cue.
4. If trunk cue is eligible on the current frame, phase cue can be blocked for that frame.
5. When trunk cue fires, pending queue is cleared but the currently playing phrase is allowed to finish.

### 6.4 Silent gates already implemented

No Squat voice should fire when:

1. `exerciseState != activated` and the exercise is not yet completed
2. `exercise.isPaused == true`
3. `hasPose == false`

Exception:

- completion logic still runs when `exerciseState == completed`, even if the current frame is otherwise not voice-eligible

---

## 7. What Is Already Correct vs. What Is Still Partial

### 7.1 Already correct in the current runtime

1. Squat voice is actually wired into `ActiveExercisePage`.
2. Ready, phase, live, rep, post-rep, and completion all exist in the same runtime path.
3. Rep-end speech is based on rep-level data finalized in `_completeRep()`, not guessed in UI.
4. Trunk cue already has highest live priority.

### 7.2 Still partial

1. Only one post-rep phrase is spoken, even though `lastRepFaultVoiceMessages` stores the full ordered list.
2. Live speech only covers `Depth` and `Back`.
3. `priority` is consumed upstream during rep finalization, not as a standalone coach rule.
4. There is no user-facing Squat-specific mute / volume setting.

---

## 8. Safe Extension Rules

If Squat voice is extended further, keep these rules:

1. Do not move TTS calls into metrics.
2. Do not teach the screen to infer rep completion or fault priority.
3. If multi-message post-rep feedback is added, consume `lastRepFaultVoiceMessages` instead of reconstructing faults from UI data.
4. If a new spoken phrase is added, update both the coach mapping and `_assetMap`.
5. Keep rep count and completion higher priority than phase/live cues.

---

## 9. Testing Checklist

### Activation / ready
- [ ] `Sẵn sàng` fires exactly once after the exercise becomes `activated`
- [ ] no voice fires before activation completes

### Phase cues
- [ ] `standing` status `Xuống` can produce `Xuống`
- [ ] `bottom` hold status maps to `Giữ`
- [ ] `bottom` release status maps to `Đứng lên`
- [ ] `ascending` status maps to `Đứng thẳng`
- [ ] `Going Down...` does not produce spoken phase audio

### Live faults
- [ ] `feedback['Depth'] = Go Lower` produces `Thấp hơn nữa`
- [ ] `feedback['Back'] = Chest up!` produces `Ưỡn ngực lên`
- [ ] trunk cue wins over depth cue when both are present
- [ ] same live phrase does not repeat faster than every 3 seconds

### Rep-end flow
- [ ] every rep increase speaks the rep number once
- [ ] post-rep feedback only plays when `lastRepWasClean == false`
- [ ] post-rep feedback is suppressed if the same phrase was already spoken live within 1.5 seconds
- [ ] same post-rep phrase does not repeat within 3 reps

### Completion
- [ ] final rep count can still be heard on the completion frame
- [ ] `Hoàn thành bài tập` fires once per set
- [ ] completion does not keep replaying on later frames

### Silent gates
- [ ] no voice while paused
- [ ] no voice while pose is missing
- [ ] no stale phase/live cue leaks after higher-priority rep/completion events

---

## 10. Bottom Line

The correct mental model for the current Squat voice implementation is:

1. `Squat` generates business data.
2. `ActiveExercisePage` forwards runtime context.
3. `SquatVoiceCoach` decides priority, cooldown, and queue behavior.
4. `ViettelTTSService` plays the actual audio.

This file documents the **current implementation**, not a future proposal. Any further work should extend this path, not redesign it from scratch.
