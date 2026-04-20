# Squat Voice — Current Runtime Spec

**For:** dev team maintenance and future extension  
**Status:** synced to the current code path in `Squat`, `SquatVoiceCoach`, `ViettelTTSService`, and `ActiveExercisePage`  
**Source of truth:**

- `lib/exercise/squat/squat.dart`
- `lib/exercise/squat/metrics/*.dart`
- `lib/services/squat_voice_coach.dart`
- `lib/services/viettel_tts_service.dart`
- `lib/screens/exercise/active_exercise_page.dart`

---

## 1. What Exists Today

### ResultIssues (`lib/exercise/exercise_base.dart`)

```dart
class ResultIssues {
  Map<String, String> feedback = {};
  Map<String, Map<String, String>> instructions = {};

  void addInstruction(String phase, String type, String message) { ... }
  void clear() { ... }
}
```

- `feedback{}` is per-frame. It is cleared at the start of `processPose()` and `processNoPoseFrame()`.
- `instructions{}` survives across frames until a new rep clears it or Squat overwrites a value.
- Squat voice reads this normalized data. It does not recalculate pose landmarks for speech.

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

- `voiceMessage` is the spoken candidate for post-rep feedback.
- `priority` is finalized upstream in Squat fault collection.
- Post-rep voice selection only considers faults with non-empty `voiceMessage`.

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

This remains the current source of truth for post-rep voice priority.

### Squat state machine (`lib/exercise/squat/squat.dart`)

```dart
enum SquatState { standing, descending, bottom, ascending }
```

What Squat already does today:

- `_updatePhaseInstructions()` writes the current `Status` instruction.
- `_completeRep()` increments `repCount`, evaluates rep-end faults, and stores:
  - `lastRepFaultVoiceMessages`
  - `lastRepTopVoiceMessage`
  - `lastRepTopVoicePriority`
  - `lastRepWasClean`
- `Squat.topVoicedFault(...)` and `Squat.orderedUniqueVoiceMessages(...)` centralize post-rep voice selection.
- `Squat.hasCompletedBottomHold` lets the coach derive the release cue even before a new phase transition happens.

### Runtime voice wiring (`lib/screens/exercise/active_exercise_page.dart`)

This path is live:

- `ActiveExercisePage` creates `SquatVoiceCoach` in `initState()` when `widget.exercise is Squat`
- `_processSquatVoiceFrame(...)` forwards runtime context into `coach.processFrame(...)`
- forwarding happens on:
  - pose frames
  - no-pose frames
  - completed frames

Note:

- on a completed pose frame, `_feedback` may still be the last activated-frame map, but the completion branch in `SquatVoiceCoach` does not depend on live feedback.

### Playback stack (`lib/services/squat_voice_coach.dart` + `lib/services/viettel_tts_service.dart`)

What already exists:

- `SquatVoiceCoach`: gating, priority, cooldown, and queue policy
- `ViettelTTSService`: singleton playback queue, local asset lookup, and Viettel API fallback
- local asset playback is used when a phrase exists in `_assetMap`; otherwise the system falls back to the Viettel TTS API

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
3. Voice reads exercise-layer data after Squat has already decided phase, faults, and rep completion.
4. Completion speech is decided inside the coach, not in the UI.

---

## 3. Voice Layers in `SquatVoiceCoach`

### 3.1 Firing order inside `processFrame(...)`

| # | Layer | When | Source | Current behavior |
|---|---|---|---|---|
| 1 | Completion branch | `exercise.exerciseState == completed` | `exerciseState`, `repCount` | final rep count can be queued first, then `Hoàn thành bài tập` |
| 2 | Silent gate | not activated, paused, or no pose | `exerciseState`, `isPaused`, `hasPose` | no speech |
| 3 | Ready branch | first active frame only | `_didAnnounceReady == false` | `clearQueue()`, speak `Sẵn sàng`, and if current phase phrase is `Xuống`, queue `Xuống` immediately |
| 4 | Live fault candidate | every active frame | `feedback` | pick the highest-priority live phrase first |
| 5 | Rep branch | `repCount > _lastRepCount` | `repCount`, Squat post-rep fields | `clearPendingButKeepCurrent()`, speak rep count, optionally enqueue one post-rep phrase, then return |
| 6 | Phase cue | phrase changed | `instructions[currentPhase]['Status']` plus derived bottom-release logic | speak if gap allows, or immediately if the bottom release cue just unlocked |
| 7 | Live fault cue | after phase evaluation | `feedback['Back']`, `feedback['Sync']`, `feedback['Depth']` | release cue can suppress live fault on that frame; otherwise trunk cue can preempt normal phase speech |

### 3.2 Completed-set behavior

| Case | Behavior |
|---|---|
| Set just completed and rep also increased on that frame | clear pending queue, speak rep count, then speak `Hoàn thành bài tập` |
| Set completed on a later frame without new rep increase | clear pending queue once, then speak `Hoàn thành bài tập` |
| Completion already announced | no repeat |

### 3.3 Silent gates

No Squat voice should fire when:

1. `exercise.exerciseState != activated` and the exercise is not yet completed
2. `exercise.isPaused == true`
3. `hasPose == false`

Exception:

- completion logic still runs when `exercise.exerciseState == completed`

Resume behavior:

- pause / no-pose resets `_lastPhasePhrase`, so the current phase cue can be spoken again after resume
- pause / no-pose does **not** reset `_didAnnounceReady`, so `Sẵn sàng` is not replayed mid-set

---

## 4. Phase Cue Behavior

Squat voice does not read raw enum names. It reads `Status` text written by Squat and also derives a bottom-release cue from `Squat.hasCompletedBottomHold`.

Current status writers in `Squat`:

| Phase | Status written by Squat |
|---|---|
| `standing` | `Xuống` |
| `descending` | `Going Down...` |
| `bottom` while hold remains | `Hold! {n}s` |
| `bottom` after hold completes | `Đứng lên` |
| `ascending` | `Đứng lên` |

Current mapping in `SquatVoiceCoach`:

| Source | Spoken phrase |
|---|---|
| `Squat.hasCompletedBottomHold == true` while still in `bottom` | `Đứng lên` |
| status starts with `Hold` or contains `Giữ` | `Giữ` |
| status contains `Xuống` | `Xuống` |
| `Squat.isReleaseStatus(status)` or status contains `Lên` | `Đứng lên` |
| status contains `Đứng thẳng` | `Đứng thẳng` |
| `Going Down...` | no spoken phase cue |

Important notes:

- `Going Down...` is intentionally silent. The anticipatory descent cue comes from `standing -> Xuống`.
- On the first active frame, the coach can queue `Sẵn sàng` then `Xuống` in the same pass.
- The previous version of this doc said the coach defers storing `Xuống` so it can replay on the next standing frame. That is **not** the current behavior. The current code stores `Xuống` immediately.
- `Đứng thẳng` is still recognized by `_phasePhraseFromStatus(...)`, but the current Squat flow does not actively emit it.

### 4.1 Release cue priority

The bottom release cue has special handling:

- if `Đứng lên` becomes available because the bottom hold just completed, the coach can speak it immediately even if the normal 250ms phase gap has not elapsed
- in that case the coach calls `clearPendingButKeepCurrent()` before queueing `Đứng lên`
- the release cue suppresses live-fault speech on that same frame

This means:

- normal trunk live voice beats ordinary phase speech
- the bottom release cue beats live-fault speech on the exact unlock frame

---

## 5. Live Fault Voice

Current live-fault source is limited to `feedback`.

| Source | Condition | Spoken phrase | Cooldown |
|---|---|---|---|
| Back | `feedback['Back']` contains `Chest up` | `Ưỡn ngực lên` | 3000ms |
| Sync | `feedback['Sync']` contains `chest up` | `Ưỡn ngực lên` | 3000ms |
| Depth | `feedback['Depth']` contains `Go Lower` | `Thấp hơn nữa` | 3000ms |

Priority rules already implemented:

1. `Ưỡn ngực lên` is the highest-priority live fault cue.
2. If trunk live cue is eligible on the current frame, ordinary phase cue can be blocked for that frame.
3. If the bottom release cue just unlocked, release cue wins and live fault is suppressed on that frame.
4. When trunk cue fires, pending queue is cleared but the currently playing phrase is allowed to finish.

No other squat metrics currently produce live voice.

---

## 6. Post-Rep Voice

### 6.1 Current rep-end selection rule

Post-rep voice is decided upstream in `Squat._completeRep()`:

1. complete depth and tempo rep-end evaluation
2. collect all metric faults for the completed rep
3. keep only faults with non-empty `voiceMessage`
4. sort by `priority`, then `type`, then `message`
5. store:
   - `lastRepFaultVoiceMessages`: ordered unique list of all spoken candidates
   - `lastRepTopVoiceMessage`: only the single highest-priority spoken phrase
   - `lastRepTopVoicePriority`
6. `SquatVoiceCoach` speaks only `lastRepTopVoiceMessage`

This means the current runtime rule is:

- only 1 post-rep instruction is spoken
- the spoken instruction is the highest-priority **voiced** fault for that rep
- silent faults do not block lower-priority voiced faults

### 6.2 Current post-rep fault-to-voice mapping

| Metric | `voiceMessage` | Priority | Spoken today |
|---|---|---|---|
| HeelRise | `Giữ gót chân` | `0` | post-rep only |
| TrunkLean forward | none | `1` | live only |
| Depth | `Xuống thấp hơn` | `2` | live uses a different phrase, post-rep uses this phrase |
| HipShoulderSync | `Ưỡn ngực lên` | `3` | can be both live and post-rep |
| Tempo | `Chậm lại` | `4` | post-rep only |
| TrunkLean backward | none | `5` | not spoken |

Important:

- `heel_rise` is the highest-priority post-rep cue.
- `hip_shoulder_sync` now reuses the chest-up phrase `Ưỡn ngực lên`.
- `tempo` still only speaks after the rep, never live.
- trunk backward lean still has no spoken phrase.

### 6.3 Notes about `lastRepWasClean`

The current code treats all current spoken squat faults as form-affecting, including heel rise:

- `correctForm = !allFaults.any((f) => f.affectsForm)`
- `lastRepWasClean = correctForm`

So even though `HeelRiseMetric` still has an old comment saying it is "informational only", the runtime behavior today is:

- heel rise makes the rep unclean
- heel rise can trigger post-rep voice

### 6.4 Post-rep gating in `SquatVoiceCoach`

Post-rep feedback is only enqueued when:

1. `exercise is Squat`
2. `exercise.lastRepWasClean == false`
3. `exercise.lastRepTopVoiceMessage` is not null or empty
4. the same post-rep phrase was not already used within the last 3 reps
5. the same phrase was not spoken live within the last 1500ms

The cooldown is phrase-based, not metric-based.

This matters because:

- `Ưỡn ngực lên` spoken live from `Back` or `Sync` can suppress a post-rep `Ưỡn ngực lên`
- the 3-rep cooldown also applies by phrase, not by fault type

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

Notes:

- default squat uses `maxRep = 15`, so all default rep counts are locally cached
- counts `16` ... `30` are also present in `_assetMap`
- if a future squat variant goes above `30`, counts beyond `30` would fall back to the API

### 7.2 Live and post-rep fault phrases emitted by the current squat flow

| Phrase | Used by current squat flow | Local asset in `_assetMap` |
|---|---|---|
| `Ưỡn ngực lên` | Yes | Yes |
| `Thấp hơn nữa` | Yes | Yes |
| `Xuống thấp hơn` | Yes | Yes |
| `Giữ gót chân` | Yes | Yes |
| `Chậm lại` | Yes | Yes |

### 7.3 Phrases present in `_assetMap` but not emitted by the current squat flow

These phrases still exist in `_assetMap`, but the current squat runtime does not emit them:

- `Nhớ không nâng gót chân`
- `Đừng nhấc hông lên trước`

This distinction matters:

- `_assetMap` is larger than the active squat phrase set
- the current source of truth for emitted phrases is the coach + metric code, not the asset map alone

### 7.4 Legacy or parseable phrases that are not part of the current emitted asset-backed flow

These phrases show up in older docs, older flow assumptions, or parser branches, but they are not part of the current emitted local-audio squat flow:

- `Đứng thẳng`
- `Sẵn sàng, xuống`
- `Sẵn sàng, lên`
- `Lên`
- `Tốt lắm`
- `Sai tư thế, chú ý`

Notes:

- `Đứng thẳng` is still parseable in the coach but is not actively emitted by the current Squat implementation.
- the other phrases above are not part of the current coach path and are not needed for the current squat runtime.

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
| `exercise.repCount` / `repCount` | rep count source of truth for voice transitions |
| `exercise.isPaused` | silence when paused |
| `hasPose` | silence when pose is missing |
| `exercise.resultIssues.instructions[currentPhaseKey]?['Status']` | phase cue source |
| `exercise is Squat && exercise.hasCompletedBottomHold` | derived bottom-release cue source |
| `feedback['Back']` | live trunk cue source |
| `feedback['Sync']` | live chest-up cue source from hip/shoulder sync |
| `feedback['Depth']` | live depth cue source |

### 8.3 Rep-end data read by the coach

| Field | Purpose |
|---|---|
| `lastRepWasClean` | decides whether post-rep feedback is eligible |
| `lastRepTopVoiceMessage` | single post-rep spoken phrase |

### 8.4 Data produced upstream but not fully consumed yet

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
| `clearPendingButKeepCurrent()` | rep count, completion, release cue, trunk live cue |
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
4. Bottom release cue can override the normal phase gap and suppress live fault on the unlock frame.
5. Post-rep priority is decided upstream by `SquatFaultVoicePriority`, with `heel_rise` highest among voiced faults.
6. Only one post-rep instruction is spoken.
7. When trunk live cue fires, pending queue is cleared but the current phrase is allowed to finish.

---

## 10. What Is Correct vs. Still Partial

### 10.1 Already correct in the current runtime

1. Squat voice is wired into `ActiveExercisePage`.
2. Ready, phase, live, rep, post-rep, and completion all exist in the same runtime path.
3. The first active frame can queue `Sẵn sàng` and `Xuống` back-to-back.
4. Rep-end speech is based on finalized rep data in `_completeRep()`, not guessed in UI.
5. Live chest-up voice can come from either `Back` or `Sync`.
6. Heel rise now speaks `Giữ gót chân`.
7. Hip-shoulder sync now speaks `Ưỡn ngực lên` post-rep.
8. All phrases currently emitted by squat have local audio in `_assetMap`.

### 10.2 Still partial

1. Only one post-rep phrase is spoken, even though `lastRepFaultVoiceMessages` stores the full ordered list.
2. Live speech is still limited to chest-up and depth cues.
3. There is still no squat-specific mute or per-exercise volume setting.

---

## 11. Safe Extension Rules

If squat voice is extended further, keep these rules:

1. Do not move TTS calls into metrics.
2. Do not teach the screen to infer rep completion or fault priority.
3. If multi-message post-rep feedback is added, consume `lastRepFaultVoiceMessages` instead of rebuilding the fault list from UI data.
4. If a new spoken phrase is added, update both the emitting code path and `_assetMap` if local cached audio is wanted.
5. Keep completion and rep count higher priority than phase and live-fault cues.
6. Preserve the special-case release cue behavior at bottom-hold completion unless product deliberately changes it.

---

## 12. Testing Checklist

### Activation / ready

- [ ] `Sẵn sàng` fires exactly once after the exercise becomes `activated`
- [ ] if the first active frame is already on `standing -> Xuống`, `Xuống` can be queued immediately after `Sẵn sàng`
- [ ] no voice fires before activation completes

### Phase cues

- [ ] `standing` status `Xuống` can produce `Xuống`
- [ ] bottom hold status maps to `Giữ`
- [ ] bottom release can produce `Đứng lên` while still in `bottom`
- [ ] ascending status maps to `Đứng lên`
- [ ] `Going Down...` does not produce spoken phase audio
- [ ] after pause / no-pose, current phase cue can replay because `_lastPhasePhrase` resets

### Live faults

- [ ] `feedback['Depth'] = Go Lower` produces `Thấp hơn nữa`
- [ ] `feedback['Back'] = Chest up!` produces `Ưỡn ngực lên`
- [ ] `feedback['Sync'] = Drive chest up!` or `Try to keep chest up` can also produce `Ưỡn ngực lên`
- [ ] trunk cue wins over ordinary phase cue when both are present
- [ ] bottom release cue suppresses live fault on the exact unlock frame
- [ ] same live phrase does not repeat faster than every 3 seconds

### Rep-end flow

- [ ] every rep increase speaks the rep number once
- [ ] post-rep feedback only plays when `lastRepWasClean == false`
- [ ] post-rep feedback chooses exactly one phrase: `lastRepTopVoiceMessage`
- [ ] heel rise wins over all other voiced post-rep faults
- [ ] silent faults do not block lower-priority voiced faults
- [ ] post-rep feedback is suppressed if the same phrase was already spoken live within 1.5 seconds
- [ ] same post-rep phrase does not repeat within 3 reps

### Completion

- [ ] final rep count can still be heard on the completion frame
- [ ] `Hoàn thành bài tập` fires once per set
- [ ] completion does not keep replaying on later frames, including no-pose frames

### Silent gates

- [ ] no voice while paused
- [ ] no voice while pose is missing
- [ ] no stale phase or live cue leaks after higher-priority rep or completion events

---

## 13. Bottom Line

The correct mental model for the current squat voice implementation is:

1. `Squat` and its metrics generate business data.
2. `ActiveExercisePage` forwards runtime context on pose and no-pose frames.
3. `SquatVoiceCoach` decides gating, priority, cooldown, and queue behavior.
4. `ViettelTTSService` plays local audio if available, otherwise falls back to the Viettel API.

This file documents the current implementation. Further work should extend this path, not redesign it from scratch.
