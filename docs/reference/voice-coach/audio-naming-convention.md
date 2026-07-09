# Voice Audio — File Naming Convention

How a logical voice **key** maps to a bundled **mp3 path**. Source of truth is
`GenericExerciseVoiceAssets.resolveAsset()` in `lib/services/generic_exercise_voice_assets.dart`;
this doc is the human-readable version for recording + dropping in new audio. If code and doc
disagree, code wins — fix this doc.

Drop a new file at the path its key resolves to and it plays automatically. No pubspec edit
needed: every `assets/audio/<slug>/` dir is registered wholesale.

## The rule

A key is either an exact **shared** key or a `<slug>.<id>` **per-exercise** key.

| Key shape | Resolves to | Example |
|---|---|---|
| `common.<name>` | must be registered in `commonFiles` map (hand-mapped) | `common.good_1` → `common/good_1.mp3` |
| rep number `"7"` | `commonFiles` count entry | `7` → `common/count_7.mp3` |
| `<slug>.<faultId>` (fault / correction line) | `<slug>/<faultId>.mp3` | `glute_bridge.speed_control` → `glute_bridge/speed_control.mp3` |
| `<slug>.<faultId>_soft` (soft cue) | `<slug>/<faultId>_soft.mp3` | `glute_bridge.knee_angle_soft` → `glute_bridge/knee_angle_soft.mp3` |
| `<slug>.setup_position` / `.active_intro` / `.good_clean` / `.hold_good` / `.set_next_setup` | `<slug>/<slug>.<id>.mp3` (slug-prefixed filename) | `glute_bridge.setup_position` → `glute_bridge/glute_bridge.setup_position.mp3` |

Notes / quirks (honest, not aspirational):
- **Fault lines are NOT slug-prefixed in the filename** (`glute_bridge/speed_control.mp3`), but
  **setup cues ARE** (`glute_bridge/glute_bridge.setup_position.mp3`). Two different filename
  shapes in the same dir — match the table, don't guess.
- `slug` for McGill Curl-up is `curl_up` but its dir is `mc_gill_curl_up`.
- A handful of slugs use plain (non-prefixed) setup filenames — see `_usesPlainCueFilenames`.
  Glute bridge is NOT one of them.
- A missing file is a **safe no-op** (logs + skips, never crashes), so audio can land incrementally.

## For future glute-bridge audio
Put fault/correction lines in `assets/audio/glute_bridge/` named `<faultId>.mp3`, where `<faultId>`
is exactly the metric's `type` string: `hip_extension`, `hyperextension`, `knee_angle`,
`speed_control`, `neck_head`. Soft cues add `_soft`. (Instruction-cue key shape is TBD — pending
the live-instruction voice wiring decision; see `state.md` in-flight.)
