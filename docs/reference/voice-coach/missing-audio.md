# Missing Audio

Running checklist for logical voice keys that the policy layer can request but
that do not have recorded assets yet.

## Recording convention — persona (ALL voice lines)

Default persona (Nam, 2026-07-10): the coach self-refers as **Vika** and addresses the user as
**bạn**, to soften tone. This pronoun scheme applies to EVERY voice line going forward — softs,
reminders, safety, praise. Two fixed copy patterns follow from it:
- **Soft fault:** `Tốt, bạn [action] chút nữa là đẹp.`
- **Reminder:** `Lần này bạn nhớ [action] nhé.`

Status tags below: **FINAL** = Nam's verbatim wording; **pattern-derived** = mechanically filled from
an existing action phrase, Nam confirms the exact string at recording time.

## V2 RE-RECORD LIST — ✅ COMPLETE (Nam recorded all groups 07-11; files on disk)

Every glute-pilot audio key now resolves to a recorded file (verified on disk 07-11 — timestamps
Jul 11). The glute bridge voice pilot has NO outstanding recording gap. Kept as the record of what
was cut and the reference wordings (the .mp3 is the source of truth for exact spoken content).

| # | What | File path | Wording (drafted; Nam's recording is canonical) | Status |
|---|---|---|---|---|
| 1 | Counts một→mười lăm (rep count-up + activation countdown reuse these) | `common/count_1.mp3` … `count_15.mp3` | Plain numbers, brisk | ✅ RECORDED (16-30 still legacy — re-record only if a plan prescribes >15) |
| 2 | `glute_bridge.speed_control` (critical: hips dropping too fast) | `glute_bridge/speed_control.mp3` | "Bạn hạ hông xuống từ từ, có kiểm soát nhé." | ✅ RECORDED |
| 3 | `glute_bridge.neck_head` (critical: head lifting off floor) | `glute_bridge/neck_head.mp3` | "Bạn giữ đầu trên sàn, mắt nhìn lên trần nhé." | ✅ RE-RECORDED (replaced the confirmed-wrong content) |
| 4 | `glute_bridge.knee_angle` (critical: heels too close) | `glute_bridge/knee_angle.mp3` | "Bạn đặt gót chân ngay dưới đầu gối nhé." | ✅ RECORDED |
| 5a/5b | Rotate to landscape / portrait | `common/rotate_landscape.mp3` / `rotate_portrait.mp3` | "Bạn xoay ngang/dọc điện thoại giúp Vika nhé." | ✅ RECORDED |
| 6a/6b | Hustle generic / final-rep push | `common/push.mp3` / `one_more_rep.mp3` | "Cố lên nào!" / "Một cái nữa thôi!" | ✅ RECORDED |

NOT needed at all: `hold_still` (unwired by ruling), `no_count`/`fix_pose`/`correct`/`keep_full_body`/
`finding_person`/`start`/`rest`/`next_set` (legacy generic-coach keys — the pilot never speaks them),
`neck_head_soft`/`hyperextension_soft` (unreachable, see soft-cue table). FLEET NOTE: this doc's
remaining sections are the glute-pilot reference; other exercises onboard their own keys at rollout.

## Glute Bridge Soft Cues

These keys are for `CueType.softFault`: measured non-critical faults that should get
a warm nudge, not a hard correction and not clean-rep praise. Pattern: `Tốt, bạn [action] chút nữa là đẹp.`

| Key | Intended line | Status |
|---|---|---|
| `glute_bridge.speed_control_soft` | Tốt, bạn hạ hông chậm hơn chút nữa là đẹp. | FINAL (Nam 07-10) — RECORDED |
| `glute_bridge.hip_extension_soft` | Tốt đấy, nâng hông cao hơn chút nữa là đẹp. | FINAL (Nam 07-10; drops the pattern's "bạn" — his wording overrides the mechanical pattern) — RECORDED |
| `glute_bridge.knee_angle_soft` | (target-state, heel-under-knee — bidirectional fault, so target framing over a direction) | RECORDED (Nam 07-10; the .mp3 is the source of truth for the exact spoken wording). Candidate was "Tốt đấy, đặt gót chân ngay dưới đầu gối là chuẩn." |
| `glute_bridge.hyperextension_soft` | ~~(soft line)~~ **DO NOT RECORD — unreachable** | Every `hyperextension` FaultRecord in glute_bridge_hip_extension.dart is `affectsForm: true` (always critical — lumbar arching is the #1 injury risk), so the soft key never fires. The critical `hyperextension` line + `hyperextension_reminder` cover it. Verified against code 2026-07-10. |
| `glute_bridge.neck_head_soft` | ~~(soft line)~~ **ON HOLD** | neck_head flipped soft→critical (07-09 lavish review); the soft path becomes unreachable once the flip lands. Do not record. |

## Glute Bridge next-rep reminder lines (`CueType.reminder`, 07-09)

Feedforward reminders spoken at the start of the next rep after a real-time-cued critical fault.
Pattern (Nam 07-10): `Lần này bạn nhớ [action] nhé.`
Timing constraint: the reminder slot is the TIGHTEST window in the system — ~1–1.5s at the rep-start
commit edge (that constraint is why reminders needed new short recordings). The persona pattern runs
longer than the old ≤7-word cap, so the rule relaxes from a word count to "keep it ~1.5s spoken,
record brisk." `hyperextension_reminder` is now 10 words — the longest line in the tightest slot, so
record it especially brisk. What-to-do framing (no "đừng" negation), warm.
Design: next-rep-instruction-design.html §06.

| Key | Line | Status |
|---|---|---|
| `glute_bridge.neck_head_reminder` | Lần này bạn nhớ giữ đầu thẳng nhé. | FINAL (Nam 07-10; content changed "giữ đầu trên sàn" → "giữ đầu thẳng") — RECORDED |
| `glute_bridge.hyperextension_reminder` | Lần này bạn nhớ siết bụng lại, giữ lưng sát sàn nhé. | FINAL (Nam 07-10; 10 words — longest line, tightest slot) — RECORDED |

## Setup / tracking-safety voice channel (`GuidanceSignal`, 07-10)

The pipeline-blocking setup/tracking-safety states now speak (design decision 07-10 + Nam's same-day
lavish review; design doc setup-safety-voice-design.html; behavior spec § "Setup / tracking-safety
guidance"). Coarse content keys: one generic body line, pause/resume, and ONE shared orientation line
per orientation mode (07-10: orientation is now a COMMON key, not per-exercise — see below). Tone: warm,
encouraging, never drill-sergeant; short. Persona per the recording convention above ("Vika" / "bạn").
`searching` deliberately has NO voice (the setup intro already covers "get in frame").

All four keys here are `common.*` HAND-MAPPED keys — each needs an entry in
`GenericExerciseVoiceAssets.commonFiles` (`resolveAsset` returns null for an unregistered `common.*` key
— the `startsWith('common.')` → null guard in generic_exercise_voice_assets.dart). All four are now
registered in the working tree AND recorded (Nam dropped the files 07-10; relocated from the staging
folder to the resolver paths below). Files live at exactly these paths:

| Key | File | Registration | Intended line | Note |
|---|---|---|---|---|
| `common.body_in_frame` | `assets/audio/common/body_in_frame.mp3` | in `commonFiles` | Vika không thấy rõ bạn, bạn giữ toàn thân trong khung hình nhé! | FINAL (Nam 07-10) — RECORDED. ONE generic line for every landmark-missing / low-confidence / lighting / tracking-loss variant. NEVER name body parts. |
| `common.paused` | `assets/audio/common/paused.mp3` | in `commonFiles` | Vika đã tạm dừng màn hình tập. | FINAL (Nam 07-10) — RECORDED. Fires on the pause commit edge, not the first lost frame. |
| `common.resume` | `assets/audio/common/resume.mp3` | in `commonFiles` | Oke, mình tiếp tục nhé! | FINAL — RECORDED. One-shot on gate resume after pause — tells the returning user reps count again. |
| `common.side_orientation` | `assets/audio/common/side_orientation.mp3` | in `commonFiles` | Bạn quay nghiêng người với màn hình nhé. | FINAL (Nam 07-10) — RECORDED. Shared SIDE-view orientation line (glute bridge needs a side view — `cameraFacing` left/right). 07-10: orientation is COMMON, not per-exercise — only ~3 orientation modes exist total, so 3 shared recordings beat N-per-exercise. Only the SIDE mode gets a key now; other modes (e.g. face-camera) get keys when an exercise needing them onboards. |

The ~10s mid-set re-cue REPLAYS the same file in v1 — no separate "fuller" recording needed yet; a
distinct fuller variant per class is a possible later addition, not on this checklist. A missing file is
a safe logged no-op, so the wiring can ship before the audio lands.

## Praise — standout ("big") line

Shared across all exercises (not glute-bridge-specific). The praise-big pool (`VoiceLib.praiseBig`,
voice_content.dart) biases toward these on a truly-clean, high-quality rep (D8 resolver bias).
`common.great_1` / `common.great_2` are now registered in `commonFiles` (was a gap: only `good_1..4`
were, so big-praise resolved to null) AND recorded.

| Key | Intended line | Status |
|---|---|---|
| `common.great_1` | Tuyệt vời! Rất chuẩn! | FINAL (Nam 07-10) — RECORDED |
| `common.great_2` | Xuất sắc lắm! Cứ giữ phong độ này nhé! | FINAL (Nam 07-10) — RECORDED |

## Renamed to convention — resolve directly, do NOT re-record

Three glute-bridge correction files were misnamed (they predated the snake_cased metric fault
ids). Renamed to the `<slug>/<faultId>.mp3` convention so the resolver's default path finds
them — no alias code, no re-recording. See `audio-naming-convention.md`.

| Cue key | File (renamed) |
|---|---|
| `glute_bridge.speed_control` | `glute_bridge/speed_control.mp3` (was `speed.mp3`) |
| `glute_bridge.neck_head` | `glute_bridge/neck_head.mp3` (was `neck.mp3`) |
| `glute_bridge.hyperextension` | `glute_bridge/hyperextension.mp3` (was `lumbar.mp3`) |

Content unchanged by the rename — sanity-check on next listen that each spoken line still fits
its renamed key. **Listen happened (Nam, device test 07-10 night): `glute_bridge.neck_head` FAILED —
the recording says the wrong thing for the fault. RE-RECORD (Nam supplies the wording; what-to-do
framing, e.g. target-state for keeping the head down/neutral — the reminder wording "giữ đầu thẳng"
is the anchor).** The other two renamed files still pending a listen.

## OPEN (Nam ruling wanted) — orientation / setup voices asked for on device (07-10 night)

Nam's device test surfaced setup moments he expected VOICE for that are currently silent by design:
- **"Rotate to landscape" — RESOLVED 07-11: RULED YES + wiring landed** (decisions.md
  "Phone-orientation guidance gets VOICE"). New keys `common.rotate_landscape`/`rotate_portrait`,
  recordings in the V2 list above (rows 5a/5b). The legacy ngang/thẳng intro files were rejected as
  the source.
- **"Move further back" (distance-specific)** — today this folds into the ONE generic
  `common.body_in_frame` line by the coarse-key anti-spam ruling (never name the remedy). It DID fire
  in Nam's session; question is whether the generic wording lands as "step back". A direction-specific
  line would be a new class + recording and re-opens the coarse-key decision.
- **"Get into position" earlier** — `setup_position` re-tell exists but only ~10s past intro-end
  (stuck-user backstop). If it should come sooner, that's the feel-tune delay knob, not new audio.

## Hustle Stage C — recorded + wired 07-11 (listen-check if needed)

The default hustle pool keys `common.one_more_rep` / `common.push` now have MP3 files in
`assets/audio/common/` and `GenericExerciseVoiceAssets.commonFiles` registrations. They are no longer
silent no-ops; keep them here only as recording provenance / listen-check notes.

## NOT missing — recorded AND wired late 07-10 (listen-checks pending, not recording tasks)

The setup-layer cues are recorded and now WIRED (uncommitted; behavior: decisions.md
"Setup-instruction voice"; voice-behavior-spec.md § Setup / structure; executed work order:
docs/scratch/setup-intro-voice-impl-spec.md): `glute_bridge.setup_position` +
`glute_bridge.active_intro` (per-set intro), `common.ready` (activation edge), `common.set_complete`
(completion), and `common/count_1..3.mp3` reused as the voiced "một/hai/ba" activation countdown.
Listen-checks for Nam (content calls, not asset gaps):
1. `set_complete.mp3` — the landed completion choice differs from legacy (`exercise_complete`); if the
   recording implies a NEXT set, the single-set pilot should speak `common.exercise_complete` instead
   (both are registered; one-line swap).
2. count_1..3 — confirm the rep-count intonation reads as a countdown in context; re-record only if it
   sounds off.
Note: `common/hold_still.mp3` is recorded but stays UNWIRED by design (holdStill has no instruction
line — the countdown owns that state's audio); don't treat it as a gap.
