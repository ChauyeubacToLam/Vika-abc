# Missing Audio

Running checklist for logical voice keys that the policy layer can request but
that do not have recorded assets yet.

## Glute Bridge Soft Cues

These keys are for `CueType.soft`: measured non-critical faults that should get
a warm nudge, not a hard correction and not clean-rep praise.

| Key | Intended line |
|---|---|
| `glute_bridge.hip_extension_soft` | Tốt, chỉ cần nâng hông cao hơn chút. |
| `glute_bridge.hyperextension_soft` | Tốt, chỉ cần giữ lưng trung lập hơn chút. |
| `glute_bridge.knee_angle_soft` | Tốt, chỉnh vị trí chân thêm chút nhé. |
| `glute_bridge.speed_control_soft` | Tốt, hạ hông chậm hơn chút nhé. |
| `glute_bridge.neck_head_soft` | Tốt, thả đầu xuống sàn thêm chút nhé. |

## Praise — standout ("big") line

Shared across all exercises (not glute-bridge-specific). `VoiceCoach` biases toward these
on a truly-clean, high-quality rep (D8 resolver bias). Missing today, so ~half of clean-rep
praise plays nothing. Lines below are candidates — Anh Doan to finalize wording.

| Key | Intended line (candidate) |
|---|---|
| `common.great_1` | Tuyệt vời! Rất chuẩn! |
| `common.great_2` | Xuất sắc lắm! Cứ giữ phong độ này nhé! |

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
its renamed key.
