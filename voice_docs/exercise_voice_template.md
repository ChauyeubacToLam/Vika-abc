# Exercise Voice Implementation Template

Use this template to implement voice for any exercise

Copy this file into a new doc (for example `push_up_voice.md`) and fill all sections.

---

## 1) Scope

- Exercise name:
- Developer:
- Status: Draft | In Progress | Ready To Test | Done

## 2) Product Goals

List what voice must achieve:

1. Phase guidance (for example: down, hold, up).
2. Rep counting.
3. Set completion announcement.
4. Critical form warnings.
5. Conflict-free playback (no spam, no stale messages).

## 3) Architecture Contract

Voice must be split into 3 layers:

1. Metrics/exercise logic: emits data and faults.
2. Voice coordinator: decides when to speak (event-driven).
3. TTS service: only queues and plays audio.

Rules:

1. Only coordinator can call `speak()`.
2. No direct `speak()` inside metric update loops.
3. Convert frame state to events before voice decisions.

## 4) Event Model

Define events used by coordinator:

1. `phaseChanged(from, to)`
2. `repCompleted(repNumber, isLastRep)`
3. `setCompleted()`
4. `faultDetected(faultType)`
5. `exercisePaused()` and `exerciseResumed()`

## 5) Voice Phrase Dictionary

Map canonical text to audio assets. Canonical text must match exactly.

| Key | Phrase | Asset file | Priority |
|---|---|---|---|
| PHASE_DESCEND |  |  |  |
| PHASE_HOLD |  |  |  |
| PHASE_ASCEND |  |  |  |
| REP_1 | 1 | 1.mp3 | High |
| REP_2 | 2 | 2.mp3 | High |
| SET_COMPLETE | "Hoàn thành bài tập" | hoan_thanh_bai_tap.mp3 | Critical |
| FAULT_1 |  |  | Medium |
| FAULT_2 |  |  | Medium |

## 6) Trigger Matrix (Required)

Fill exact condition -> voice output mapping.

| Event | Condition | Phrase | Cooldown | Once Per Rep | Drop Rules |
|---|---|---|---|---|---|
| phaseChanged | standing -> descending |  | 700ms | No | Drop if repCompleted fires same frame |
| phaseChanged | descending -> bottom |  | 700ms | No | Drop if paused |
| phaseChanged | bottom -> ascending |  | 700ms | No | Keep |
| repCompleted | repCount increased | number | none | N/A | Replace low-priority pending |
| setCompleted | exercise completed | "Hoàn thành bài tập" | none | N/A | Preempt all pending |
| faultDetected | ... | ... | 3000ms | Yes | Skip if same fault already spoken in rep |

## 7) Priority and Conflict Policy

Define strict priority from high to low:

1. Set completion
2. Rep count
3. Critical faults
4. Phase cues
5. Low-value reminders

Queue policy:

1. `clearQueue()` on new rep start only if stale pending phrases are harmful.
2. Never clear blindly every frame.
3. Keep currently playing audio unless a critical event requires interruption.

## 8) Coordinator State Requirements

Minimum internal state:

1. `lastPhase`
2. `lastRepCount`
3. `lastExerciseState`
4. `lastSpokenAtByKey`
5. `spokenFaultInCurrentRep`
6. `didAnnounceSetComplete`

## 9) Critical Methods Checklist

TTS service:

1. `Future<void> speak(String text)`
2. `void clearQueue()`

Voice coordinator:

1. `void onFrame(VoiceFrameSnapshot snapshot)`
2. `void onRepCompleted(int rep, {required bool isLastRep})`
3. `void onSetCompleted()`
4. `void reset()`
5. `void dispose()`

Optional (recommended):

1. `Future<void> speakPriority(String text, {bool flush = false})`
2. `void clearPendingButKeepCurrent()`

## 10) Integration Steps

1. Initialize coordinator in active page `initState()`.
2. Build `VoiceFrameSnapshot` after each `processPose(...)` result.
3. Call `voiceCoordinator.onFrame(snapshot)` once per processed frame.
4. Handle completion guard: speak set complete only once.
5. Dispose coordinator and clear queue in `dispose()`.

## 11) VoiceFrameSnapshot Template

```dart
class VoiceFrameSnapshot {
  final String exerciseId;
  final String exerciseState;
  final String phaseKey;
  final int repCount;
  final bool isPaused;
  final bool hasPose;
  final Map<String, String> feedback;
  final Map<String, Map<String, String>> instructions;
  final int timestampMs;

  const VoiceFrameSnapshot({
    required this.exerciseId,
    required this.exerciseState,
    required this.phaseKey,
    required this.repCount,
    required this.isPaused,
    required this.hasPose,
    required this.feedback,
    required this.instructions,
    required this.timestampMs,
  });
}
```

## 12) Acceptance Criteria

Functional:

1. Correct phrase at correct transition.
2. Rep number spoken exactly once per rep.
3. Set completion spoken exactly once.
4. Fault cues are throttled and not spammed.
5. No stale messages from previous rep.

Stability:

1. Works under low FPS and jitter.
2. Works after camera switch.
3. Works after app pause/resume.

Localization:

1. Phrase keys exactly match canonical dictionary.
2. All required assets exist.

## 13) Testing Plan

Run and record these tests:

1. Perfect form set.
2. Repeated same fault in one rep.
3. Alternating different faults.
4. Rapid transition jitter.
5. Person leaves frame and returns.
6. Last rep completion path.

For each test capture:

1. Timeline of events.
2. Spoken sequence.
3. Queue decisions (enqueue, drop, clear).

## 14) Remaining Problems
- List remaining problems here if needed.