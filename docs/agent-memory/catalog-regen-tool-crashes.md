---
name: catalog-regen-tool-crashes
description: exercise catalog generator crashes on FFI in this env; regen by patching the JSON from prod via Supabase MCP
metadata:
  type: reference
---

`dart run tool/generate_exercise_catalog.dart` (regenerates `assets/data/exercise_catalog.json`
from the Supabase `exercise_catalog` table) CRASHES in this env with a native-assets/FFI compiler
error: `type 'InvalidType' is not a subtype of type 'FunctionType'` in `_FfiUseSiteTransformer`.
Cause: the tool imports `models/exercise_definition.dart`, which transitively pulls the camera /
mlkit plugins' FFI, and the SDK's FFI transformer chokes building that graph as a standalone script.
Not a script or data bug.

Workaround (verified 2026-07-12): regenerate the JSON WITHOUT the tool. The file mirrors these prod
columns per row — `sets`(base_sets), `reps`(base_reps), `seconds`(base_seconds), `isFormChecked`
(is_form_checked), plus `vietnameseName`/`englishName`. The structural fields `definitionId` /
`classKey` are a deterministic resolution of `id` and DON'T change on a data migration, so patch the
existing JSON in place: `SELECT id, base_sets, base_reps, base_seconds, is_form_checked FROM
public.exercise_catalog ORDER BY id` via Supabase MCP, then for each entry match by `catalogId` and
overwrite those four fields. Write with `json.dumps(data, indent=2, ensure_ascii=False)+"\n"` to keep
the diff minimal (2-space indent, raw UTF-8, trailing newline — matches the tool's output). Assert
the JSON's catalogId set == prod id set first so an added/removed row can't be silently missed.

Note: the bundled JSON has historically been hand-edited and drifts from prod (form flags, seconds
values). A regen resyncs to prod truth, so expect a diff wider than whatever row you just changed —
eyeball the full change list, don't assume only your row moved.
