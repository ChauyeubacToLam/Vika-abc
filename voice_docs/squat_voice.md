# Squat Voice Implementation

Use this document as the Squat-specific implementation based on the shared voice template.

---

## 1) Scope

- Exercise name: Squat
- Developer: Doan Duc Anh
- Status: Implemented (runtime-integrated)

## 2) Product Goals

Squat voice must achieve the following:

1. Guide movement phases clearly.
2. Count reps accurately.
3. Announce set completion.
4. Warn on critical form issues.
5. Avoid voice conflicts (no spam, no stale messages).

## 3) Architecture Contract

Voice implementation must be split into 3 layers:

1. Squat metrics and exercise state machine emit frame data and faults.
2. `ExerciseScreen` contains an inline voice coordinator (`_processSquatVoiceFrame`).
3. `ViettelTTSService` queues and plays audio.

Rules:

1. Only the coordinator calls `speak()`.
2. Never call `speak()` directly from metric `update()` loops.
3. Convert frame/state changes into voice events before deciding speech.

## 4) Event Model

Current implementation processes these events:

1. `frameProcessed(hasPose, exerciseState, phaseKey, isPaused, statusText)`
2. `phaseCueChanged(phaseKey/statusText)` with cooldown gating
3. `repCompleted(repCountIncreased)`
4. `setCompleted(guardedOnce)`
5. `faultDetectedFromLiveFeedback(feedback)`

Note:

1. Pause/no-pose states gate speech output (no pause/resume phrase is spoken).

## 5) Voice Phrase Dictionary

Canonical phrases must match TTS asset keys exactly.

| Key | Phrase | Asset file | Priority |
|---|---|---|---|
| PHASE_DESCEND | "Xuống" | xuong.mp3 | Low |
| PHASE_HOLD | "Giữ" | giu.mp3 | Low |
| PHASE_ASCEND | "Đứng lên" | dung_len.mp3 | Low |
| PHASE_FINISH | "Đứng thẳng" | dung_thang.mp3 | Low |
| REP_1..REP_30 | "1".."30" | 1.mp3..30.mp3 | High |
| SET_COMPLETE | "Hoàn thành bài tập" | hoan_thanh_bai_tap.mp3 | Critical |
| FAULT_DEPTH | "Thấp hơn nữa" | thap_hon_nua.mp3 | Medium |
| FAULT_TRUNK_LEAN | "Ưỡn ngực lên" | uon_nguc_len.mp3 | Medium |

## 6) Trigger Matrix (Required)

| Event | Condition | Phrase | Cooldown | Once Per Rep | Drop Rules |
|---|---|---|---|---|---|
| phaseCueChanged | `phaseKey` or `statusText` changes while activated, not paused, has pose | status-mapped phrase (`Xuống`/`Giữ`/`Đứng lên`/`Đứng thẳng`) | 700ms | No | Skip when cooldown not elapsed |
| repCompleted | `repCount` increases | `<repNumber>` | none | N/A | Calls `clearQueue()` first, then enqueues rep number |
| faultDetectedFromLiveFeedback | `feedback['Depth']` indicates shallow depth (`Go Lower`) | "Thấp hơn nữa" | 3000ms per phrase | Yes | Skip if spoken within cooldown |
| faultDetectedFromLiveFeedback | `feedback['Back']` indicates forward lean (`Chest up`) | "Ưỡn ngực lên" | 3000ms per phrase | Yes | Skip if spoken within cooldown |
| setCompleted | exercise state becomes completed | "Hoàn thành bài tập" | none | N/A | Calls `clearQueue()`, speaks once with completion guard |

## 7) Priority and Conflict Policy

Priority from high to low:

1. Set completion
2. Rep count
3. Fault warnings
4. Phase cues

Queue policy:

1. Call `clearQueue()` on rep completion before speaking rep count.
2. Never clear queue every frame.
3. Call `clearQueue()` on set completion before final announcement.

## 8) Coordinator State Requirements

Minimum state to track:

1. `_lastVoiceExerciseState`
2. `_lastVoicePhaseKey`
3. `_lastVoiceStatusText`
4. `_lastVoiceRepCount`
5. `_lastPhaseCueAtMs`
6. `_lastFaultVoiceAtMs`
7. `_didAnnounceSetCompleteVoice`

## 9) Critical Methods Checklist

TTS service:

1. `Future<void> speak(String text)`
2. `void clearQueue()`

Voice coordinator:

1. `void _processSquatVoiceFrame({required bool hasPose})`
2. `String? _phasePhraseFromStatus(String? statusText)`

Optional (recommended):

1. `Future<void> speakPriority(String text, {bool flush = false})`
2. `void clearPendingButKeepCurrent()`

## 10) Integration Steps

1. Initialize TTS service and voice state fields in `ExerciseScreen`.
2. After each processed frame, call `_processSquatVoiceFrame(hasPose: true/false)`.
3. In `_processSquatVoiceFrame`, gate by activated state, pose presence, and pause state.
4. During activated frames, map live feedback to fault voices and speak with per-phrase cooldown.
5. On rep completion (`repCount` increase), call `clearQueue()` and speak rep count.
6. On set completion, call `clearQueue()` and speak completion once.
7. In `dispose()`, call `clearQueue()` for squat sessions.

## 11) Runtime Inputs Used by Coordinator

`_processSquatVoiceFrame` currently reads:

1. `exerciseState`
2. `currentPhaseKey`
3. `repCount`
4. `isPaused`
5. `hasPose`
6. `resultIssues.instructions[currentPhaseKey]['Status']`
7. Live feedback map (`Depth`, `Back` keys)
8. Current timestamp (`DateTime.now().millisecondsSinceEpoch`)

## 12) Acceptance Criteria

Functional:

1. "Xuống", "Giữ", "Đứng lên", "Đứng thẳng" are spoken via phase/status change events with 700ms cooldown.
2. Phase cues are anticipatory: they must instruct the next action, not describe current movement.
3. Each completed rep speaks one number exactly once.
4. "Hoàn thành bài tập" is spoken exactly once at completion.
5. "Thấp hơn nữa" and "Ưỡn ngực lên" are throttled and do not spam.
6. No stale phrases from previous reps are heard.

Stability:

1. Behavior remains correct under low FPS and phase jitter.
2. Behavior remains correct after camera switch.
3. Behavior remains correct after app pause/resume.

Localization:

1. Phrase text exactly matches canonical TTS keys.
2. Required assets exist for all Squat phrases.

## 13) Testing Plan

Run and capture these tests:

1. Perfect Squat rep flow (`"Xuống" -> "Giữ" -> "Đứng lên" -> "Đứng thẳng" -> rep number`) with cues spoken before the corresponding movement.
2. Repeated shallow reps (verify `"Thấp hơn nữa"` cooldown).
3. Repeated trunk lean faults (verify `"Ưỡn ngực lên"` cooldown).
4. Rapid phase jitter due to noisy input.
5. Person leaves frame and returns.
6. Final rep and completion announcement.

For each test, record:

1. Event timeline.
2. Spoken sequence.
3. Queue decisions (enqueue, drop, clear).


