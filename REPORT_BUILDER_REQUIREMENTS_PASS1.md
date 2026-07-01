# Report-builder requirements — PASS 1 (draft, no code)

Scope: the 19 exercises named in the task. Goal of this pass: extract exact, verbatim
requirements (fault keys, `isSecondBased`, MET, interpreter status) and draft the Vietnamese
*idea* per fault. **No builder code in this pass.** Nam rewrites the Vietnamese; the drafts here
only need to carry the right idea and obey the copy rules (external cueing, encouraging, no em
dashes).

Reference read for the pattern: [squat_report_builder.dart](lib/exercise/squat/squat_report_builder.dart),
the base class [post_exercise_data.dart](lib/models/post_exercise_data.dart#L139), the registry
[report_builder_registry.dart](lib/exercise/report_builder_registry.dart).

---

## 0. READ THIS FIRST — the brief is stale

The task says "only `squat` / `squat_assessment` are registered; every other exercise falls back to
`GenericReportBuilder` with an empty `faultToTipMap`." **That is no longer true of the code on this
branch.** Current reality:

| # | Exercise | Builder file? | Registered? | `isSecondBased` | MET | Fault keys emitted? | What this exercise actually needs |
|---|---|---|---|---|---|---|---|
| 1 | `high_plank` | yes | yes | **true** | 3.5 | yes | verify/refine only |
| 2 | `bear_plank` | yes | yes | **true** | 3.5 | yes (duplicated) | clean up dup keys |
| 3 | `plank_up_down` | yes | yes | false | 4.5 | yes | verify/refine only |
| 4 | `plank_shoulder_tap` | yes | **NO** | false | propose 3.5 | yes, but **no `max_rep`** | register + fix score bug |
| 5 | `mountain_climber` | yes | **NO** | false | propose 8.0 | yes | register |
| 6 | `sit_up` | yes | yes | false | 3.8 | yes | verify/refine only |
| 7 | `v_up` | yes | yes | false | 4.0 | yes | fix pain vocab + tip gaps |
| 8 | `reverse_crunch` | yes | yes | false | 3.5 | yes | fill 1 tip gap |
| 9 | `leg_raise` | yes | yes | false | 3.5 | yes, but **no `max_rep`** | fix score bug + tip gaps |
| 10 | `dead_bug` | yes | yes | false | 3.0 | yes | fill 1 tip gap |
| 11 | `bird_dog` | yes | yes | false | 3.5 | yes | refine copy (internal cueing) |
| 12 | `superman` | yes | yes | false | 3.5 | yes | verify/refine only |
| 13 | `curl_up` | **NO** | **NO** | false | propose 3.5 | **yes** | **BUILD (keys ready)** |
| 14 | `glute_bridge` | **NO** | commented | false | propose 3.5 | **NO — `onSetComplete(){}` empty** | **BLOCKED on exercise wiring** |
| 15 | `push_up` | **NO** | **NO** | false | propose 3.8 | **yes** | **BUILD (keys ready)** |
| 16 | `plank` | yes | yes | **true** | 3.5 | yes | already clean |
| 17 | `lunge` | **NO** | **NO** | false | propose 4.5 | **NO — `onSetComplete(){}` empty** | **BLOCKED on exercise wiring** |
| 18 | `jumping_jack` | **NO** | **NO** | false | propose 8.0 | **NO — `onSetComplete(){}` empty** | **BLOCKED on exercise wiring** |
| 19 | `warrior_one` | yes | yes | **true** | 3.0 | yes | already clean |

So the real PASS-2 work is much smaller than "write 19 builders":

- **Build from ready keys (2):** `curl_up`, `push_up`.
- **Register existing builders (2):** `mountain_climber`, `plank_shoulder_tap` (one-line registry entries; `plank_shoulder_tap` also needs the score bug fixed first).
- **Blocked on exercise-level wiring (3):** `glute_bridge`, `lunge`, `jumping_jack` — their `onSetComplete()` is literally `{}`, so they emit **no fault keys, no `max_rep`, no `good_rep_count`**. A builder cannot be written until the exercise is wired to push faults. Keys CANNOT be extracted; I did not invent any.
- **Verify / refine (12):** the already-registered + file-only builders. Several have real correctness issues (below).

---

## 1. Cross-cutting findings (apply to all 19)

### F1 — No interpreter exists, so every `detectIssue()` returns `null` today
Only `SquatInterpreter` extends `InterpreterBase`. No other exercise has one. Every one of the 14
existing builders implements `detectIssue() => null`. The `interpretingMap`
([intepreting_map.dart](lib/interpreter/intepreting_map.dart)) issue keys are **squat-specific**
(`ankle_mobility`, `limited_mobility`, `ankle_mobility_restriction`, `hip_flexor_overactivity`)
plus a block of `priority: 99` **self-report** entries that the comment says are "never emitted by
an interpreter."

**Consequence:** there are *no measured interpreter issues to map* for any of the 19. Every
`detectIssue` confirmation question in this doc is a **PROPOSAL** — it would require either a new
lightweight interpreter or inline `detectIssue` logic reading the exercise's own fault counts. All
such proposals are marked clinical-verify (Nam's call), per the brief. The asserted coaching still
comes only from MEASURED fault counts via `faultToTipMap`; `detectIssue` stays a Có/Không question,
never a fact.

### F2 — Pain-area vocabulary is inconsistent across the app, and there is no normalizer (HIGH IMPACT)
The brief says the onboarding vocab is `ankle, lower_back, knee, hip, shoulder, neck, other`. The
code disagrees, and disagrees with itself:

| Source | Vocabulary it uses |
|---|---|
| Brief (this task) | `ankle, lower_back, knee, hip, shoulder, neck, other` |
| **Onboarding S04** ([v5_models.dart `painAreaOptions`](lib/screens/onboarding/v5/v5_models.dart#L152)) — what actually persists to `user_pain_areas` | `back` (labeled "Lưng dưới"), `neck` (labeled "Cổ · Vai · Gáy"), `knee`, `hip`, `wrist`, `other` |
| Progress heat-map ([body_heat_map.dart](lib/widgets/progress/body_heat_map.dart#L107)) | `shoulder_neck`, `back`, `lower_back`, `hip`, `wrist`, `knee`, `ankle`, `other` |
| Interpreter `bodyRegion` | `ankle`, `hip`, `lower_back`, `shoulder`, `knee`, ... |

`painToFaultMap` is matched by **exact string** (`painToFaultMap[pain]` in
[exercise_comparison_service.dart](lib/services/exercise_comparison_service.dart#L63) and the base
praise ladder). **No back↔lower_back or neck↔shoulder_neck normalizer exists.** Therefore:

- Every existing builder keys pain on **`lower_back`** and **`shoulder`** — neither is in the S04
  onboarding set, so if onboarding is the source of `user_pain_areas`, **those pain links never
  fire.** Onboarding emits `back` and `neck`, not `lower_back`/`shoulder`.
- `v_up` keys pain on **`hamstring`**, which is in *no* vocabulary — dead link.
- `wrist` IS valid in onboarding/heat-map (so the earlier instinct that `wrist` is invalid is wrong);
  it is the brief's list that omits it.

**Recommendation (Nam decides):** pick ONE canonical pain vocab and either migrate the builders to it
or add a normalizer at the `user_pain_areas` read boundary. Until then, treat every `painToFaultMap`
below as provisional. In the drafts I use the brief's term and annotate the onboarding-actual term in
brackets, e.g. `lower_back [S04 persists 'back']`.

### F3 — Most existing builders duplicate `watch` == `next` and cue internally
Squat's pattern is `watch` = a noticing line ("Để ý gót chân...") and `next` = a forward external
cue ("Giữ trọng lượng dồn vào gót..."). Most of the 14 set `watch` and `next` to the **same string**,
and several cue the muscle/joint ("co cơ...", "duỗi gối") instead of the action/feel. `plank` and
`warrior_one` are the two that already do it right (distinct watch/next, external cues) — use them as
the in-repo template alongside squat. The reverse-lookup in `_closedCoachingLoop` matches on `.next`,
so duplication doesn't crash, but it wastes the "noticing vs do-this" split.

### F4 — Fault-count keys must end in `_fails_count` or `_fails`
The base aggregator
([`_aggregateFaultCounts`](lib/models/post_exercise_data.dart#L565)) only sums setLog keys ending in
`_fails_count` or `_fails`. Every key below already satisfies this. Telemetry keys
(`left_lead_count`, `rejected_attempts_count`, `rom_good_count`, etc.) deliberately do **not**, so
they are ignored by coaching — correct.

### F5 — `isSecondBased` is broader than the brief expected
Brief expected only `high_plank` and `bear_plank`. Code has **four** time-under-tension holds:
`high_plank`, `bear_plank`, **`plank`**, **`warrior_one`** — all four set `isSecondBased => true` and
emit `total_seconds`/`good_seconds`. This is correct, not a bug; the brief's family grouping just
under-counted. Everything else is rep-scored.

### F6 — Two score-killing bugs: missing `max_rep`
`leg_raise` and `plank_shoulder_tap` never push `max_rep` in `onSetComplete()`
(`pushGoodRepCount()` sets only `good_rep_count`, [logger](lib/utils/exercise_logger.dart#L49)). For
a rep-scored exercise the base computes `score = max_rep > 0 ? good/maxRep*100 : 0`, so **both score
0 every set** and produce no praise. Must push `max_rep` before their builders mean anything.

---

## 2. HOLD / ISOMETRIC family

### 2.1 `high_plank` — builder ✓, registered ✓, `isSecondBased` true, MET 3.5
Keys via `.faults.length` (not `.faultsCount`, same effect),
[high_plank.dart#L271](lib/exercise/3.High%20Plank/high_plank.dart#L271).

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `sagging_fails_count` | hips drop, lumbar sag | Kéo rốn về phía cột sống, giữ hông ngang vai | Không một giây võng lưng, lõi rất chắc |
| `piked_fails_count` | hips pike up (too easy) | Hạ hông xuống thẳng hàng vai tới gót | Giữ thân phẳng, đúng tầm core |
| `elbow_fails_count` | elbow not stacked / bent | Đẩy sàn ra xa, khóa cùi chỏ dưới vai | Tay trụ vững suốt thời gian giữ |

praiseMetricNames: `sagging_fails_count`→"Cột sống phẳng", `piked_fails_count`→"Form chuẩn" (elbow
not praised — fine). detectIssue: **PROPOSAL** — if `sagging` dominates, ask `low_back_pain`
question "Bạn có thấy đau lưng dưới khi giữ plank không?" (threshold: sagging frames > ~40% of hold).
painToFaultMap (current, OK after vocab fix): `lower_back`→[sagging], `shoulder`→[piked, elbow].
Status: copy currently duplicates watch==next; refine per F3, otherwise complete.

### 2.2 `bear_plank` — builder ✓, registered ✓, `isSecondBased` true, MET 3.5
Active tip keys are the **non-`_count`** variants. [bear_plank.dart#L296-301](lib/exercise/14.Bear%20Plank/bear_plank.dart#L296)
emits BOTH `knee_fails`+`knee_fails_count`, `back_fails`+`back_fails_count`, `weight_fails`+`weight_fails_count` (same values) → **double-counts in the aggregate.** Cleanup: emit one variant only.

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `knee_fails` | knees hover too high (>~10cm) | Giữ gối sát sàn, hover thấp như tờ giấy | Gối sát đất, lõi gánh đúng lực |
| `back_fails` | lumbar sag under load | Cuộn xương chậu, tưởng tượng giữ ly nước trên lưng | Lưng phẳng suốt set, an toàn |
| `weight_fails` | shoulders drift forward of wrists | Dồn vai thẳng trên cổ tay, đừng rướn tới | Vai trên cổ tay, cân bằng tốt |

detectIssue: **PROPOSAL** — `back_fails` dominant → `low_back_pain` confirm. painToFaultMap (current):
`lower_back`→[back_fails], `wrist`→[weight_fails], `knee`→[knee_fails]. `wrist`+`knee` are valid
onboarding ids; `lower_back` → see F2.

---

## 3. PLANK-BASE REP family

### 3.1 `plank_up_down` — builder ✓, registered ✓, rep-scored, MET 4.5
[plank_up_down.dart#L505-507](lib/exercise/13.Plank%20Up-Down/plank_up_down.dart#L505). No
praiseMetricNames (generic praise fallback — fine).

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `trunk_sagging_fails` | lumbar sag on transition | Siết bụng, cuộn chậu trước khi đẩy tay lên | Lên xuống không võng lưng |
| `hip_rotation_fails` | hips rock side to side | Mở chân rộng hơn vai cho chân đế vững | Hông đứng yên, chống xoay tốt |
| `arm_extension_fails` | arms don't lock at top | Duỗi thẳng tay ở pha cao để dồn vào tay sau | Khóa tay chuẩn ở đỉnh |

detectIssue: **PROPOSAL** — `trunk_sagging` dominant → `low_back_pain` confirm. painToFaultMap
(current): `lower_back`→[trunk_sagging], `shoulder`→[arm_extension, hip_rotation],
`wrist`→[arm_extension]. (`wrist` valid; `lower_back`/`shoulder` see F2.)

### 3.2 `plank_shoulder_tap` — builder ✓, **NOT registered**, rep-scored, MET propose 3.5
[plank_shoulder_tap.dart#L366-369](lib/exercise/7.Plank%20Shoulder%20Tap/plank_shoulder_tap.dart#L366).
**Bug F6: no `max_rep` pushed → scores 0.** Tip gap: `tempo_fails` is emitted but has no tip.

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `rotation_fails` | hips twist when lifting a hand | Mở chân rộng, siết bụng, không để hông lắc | Hông đóng băng, chống xoay tốt |
| `alignment_fails` | sag/pike, body not one line | Giữ thân thành một đường căng, không chổng mông | Trục lưng thẳng tắp |
| `tap_fails` | tap not clean/decisive | Chạm vai đối diện dứt khoát rồi đặt tay lại | Chạm vai gọn, kiểm soát trọng tâm |
| `tempo_fails` **(no tip yet)** | reps rushed / slamming hand down | Tap chậm và đều, không đập tay xuống sàn | Nhịp tay đều, kiểm soát tốt |

praiseMetricNames: rotation→"AntiRot", alignment→"Alignment". detectIssue: **PROPOSAL** — `rotation`
dominant → `low_back_pain` or `shoulder_pain` confirm. painToFaultMap (current):
`lower_back`→[rotation, alignment], `wrist`→[tempo], `shoulder`→[rotation]. To register: add
`'plank_shoulder_tap': (builder: PlankShoulderTapReportBuilder(), met: 3.5)` — **after** fixing the
`max_rep` bug.

### 3.3 `mountain_climber` — builder ✓, **NOT registered**, rep-scored, MET propose 8.0
[mountain_climber.dart#L393-394](lib/exercise/4.Mountain%20Climber/mountain_climber.dart#L393). MET
8.0 ≈ vigorous calisthenics (compendium). Builder has a commented-out `core_weakness` detectIssue
that references a non-existent `interpretingMap` issue — leave returning null until F1 is resolved.

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `trunk_fails_count` | hips bounce / lumbar sag | Siết bụng, cuộn xương cụt nhẹ, giữ lưng phẳng | Giữ form lưng phẳng, lõi rất ổn |
| `rom_fails_count` | knee not driven far enough | Kéo gối lên ngang rốn mỗi nhịp | Biên độ gối sâu, đốt mỡ tốt |

praiseMetricNames: trunk→"Core", rom→"ROM". detectIssue: **PROPOSAL** — `trunk` dominant →
`low_back_pain` confirm. painToFaultMap (current): `lower_back`/`shoulder`/`wrist` all →
[trunk_fails_count]. To register: `'mountain_climber': (builder: MountainClimberReportBuilder(), met: 8.0)`.

---

## 4. SUPINE FLEXION family

### 4.1 `sit_up` — builder ✓, registered ✓, rep-scored, MET 3.8
[sit_up.dart#L167-170](lib/exercise/2.Sit-Up/sit_up.dart#L167).

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `rom_fails_count` | trunk doesn't reach ~90° | Lên cho thân vuông góc, chạm tới mục tiêu | Lên đủ tầm, kích cơ tối đa |
| `jerking_fails_count` | jerks up with momentum | Lên chậm bằng cơ bụng, không giật | Lên xuống mượt, cột sống an toàn |
| `stability_fails_count` | hip flexors take over, feet lift | Khóa bàn chân xuống thảm, để bụng kéo | Chân neo chắc, đúng cơ bụng |
| `tempo_fails_count` | drops back down uncontrolled | Hạ người trong 2 giây, đừng thả rơi | Hạ có kiểm soát, gồng bụng tốt |

praiseMetricNames: jerking→"Mượt mà", stability→"Cố định", tempo→"Kiểm soát" (rom not praised — fine).
detectIssue: **PROPOSAL** — `jerking`/`stability` dominant → `low_back_pain` confirm. painToFaultMap
(current): `lower_back`→[jerking], `hip`→[stability].

### 4.2 `v_up` — builder ✓, registered ✓, rep-scored, MET 4.0
[v_up.dart#L155-159](lib/exercise/10.Vup/v_up.dart#L155). **Two issues:** (a) `knee_fails_count` and
`tempo_fails_count` are emitted but have **no tip**; (b) painToFaultMap keys `hamstring`, which is in
no vocab (F2) — dead link.

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `sync_fails_count` | hands/feet rise out of sync | Tưởng tượng tay và chân nối bằng một sợi dây | Đồng bộ tay chân, rất chuẩn |
| `rom_fails_count` | not folding into a full V | Ép bụng về phía đùi sâu hơn thành chữ V | Gập chữ V gắt, biên độ tốt |
| `jerking_fails_count` | yanks up with momentum | Lên bằng sức căng bụng, không giật | Lên không quán tính, mượt |
| `knee_fails_count` **(no tip yet)** | knees bend instead of straight legs | Giữ chân thẳng khi gập, duỗi dài qua gót | Chân thẳng, biên độ đẹp |
| `tempo_fails_count` **(no tip yet)** | lowers too fast | Hạ tay chân chậm lại, giữ bụng gồng | Hạ có kiểm soát, đúng nhịp |

praiseMetricNames: sync→"Hiệp đồng", rom→"Biên độ", jerking→"Trơn tru". detectIssue: **PROPOSAL** —
`sync`/`jerking` dominant → `low_back_pain` confirm. painToFaultMap (proposed fix): `lower_back`→[sync,
jerking], `knee`→[knee_fails_count] (replace the dead `hamstring`→[knee_fails_count]; `knee` is a
valid onboarding id and knee straightness is gated by hamstring tightness so the link still reads).

### 4.3 `reverse_crunch` — builder ✓, registered ✓, rep-scored, MET 3.5
[reverse_crunch.dart#L386-389](lib/exercise/9.Reverse%20Crunch/reverse_crunch.dart#L386). Tip gap:
`arm_position_fails` emitted, no tip.

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `momentum_fails` | swings legs instead of curling | Dùng bụng dưới kéo gối về ngực, giữ góc chân 90° | Cô lập tốt, không vung chân |
| `curl_fails` | hips don't lift off the mat | Cuộn xương chậu, nhấc mông khỏi thảm | Biên độ sâu, cuộn chậu đẹp |
| `tempo_fails` | lowers legs too fast | Hạ chân từ từ trong 2 giây, gồng bụng | Hạ kiểm soát, không thả rơi |
| `arm_position_fails` **(no tip yet)** | arms push off floor for leverage | Đặt tay nhẹ xuống sàn, để bụng làm việc | Tay yên, đúng cơ bụng dưới |

praiseMetricNames: momentum→"Isolation", curl→"Pelvic". detectIssue: **PROPOSAL** — `momentum`/`curl`
dominant → `low_back_pain` confirm. painToFaultMap (current): `lower_back`→[momentum, curl].

### 4.4 `leg_raise` — builder ✓, registered ✓, rep-scored, MET 3.5
[leg_raise.dart#L327-331](lib/exercise/8.Leg%20Raises%20(Supine)/leg_raise.dart#L327). **Bug F6: no
`max_rep` → scores 0.** Tip gaps: `rom_fails_count`, `arm_position_fails_count` emitted, no tip.

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `pelvic_fails_count` | lower back arches off floor | Ép thắt lưng xuống thảm, đừng hạ chân quá thấp | Lưng sát sàn, khung chậu an toàn |
| `tempo_fails_count` | legs drop fast, yanks spine | Kìm chân lại khi hạ, không rơi tự do | Kiểm soát nhịp hạ, rất tốt |
| `knee_fails_count` | knees bend (hamstring tightness) | Giữ chân thẳng vừa sức, duỗi dài qua gót | Duỗi gối đẹp, chân thẳng |
| `rom_fails_count` **(no tip yet)** | legs don't reach full range | Nâng chân lên hết tầm rồi mới hạ | Biên độ đủ, đúng cơ |
| `arm_position_fails_count` **(no tip yet)** | arms push for leverage | Đặt tay nhẹ hai bên, để bụng giữ chân | Tay yên, đúng bụng dưới |

praiseMetricNames: pelvic→"Khóa chậu", tempo→"Nhả cơ", knee→"Đôi chân". detectIssue: **PROPOSAL** —
`pelvic` dominant → `low_back_pain` confirm. painToFaultMap (current): `lower_back`→[pelvic, tempo],
`knee`→[knee_fails_count].

---

## 5. ANTI-EXTENSION family

### 5.1 `dead_bug` — builder ✓, registered ✓, rep-scored, MET 3.0
[dead_bug.dart#L178-182](lib/exercise/12.Dead%20Bug/dead_bug.dart#L178). Tip gap:
`floor_contact_fails_count` emitted, no tip.

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `anti_extension_fails_count` | lower back lifts off floor | Hít sâu, ép thắt lưng xuống thảm và giữ | Khóa lưng tuyệt đối, core thép |
| `coordination_fails_count` | same-side limbs move together | Duỗi tay và chân đối bên cùng lúc | Phối hợp chéo chính xác |
| `stable_limbs_fails_count` | resting limbs don't stay frozen | Hai chi nghỉ "đóng băng", chỉ hai chi làm việc | Chi trụ bất động, cô lập tốt |
| `tempo_fails_count` | moves too fast | Càng chậm càng tốt, tập thần kinh cơ | Nhịp chậm chuẩn, kiểm soát tốt |
| `floor_contact_fails_count` **(no tip yet)** | back loses contact with floor | Giữ lưng luôn chạm thảm suốt động tác | Lưng dán sàn suốt rep |

praiseMetricNames: anti_extension→"Khóa lưng", coordination→"Não bộ", stable_limbs→"Cô lập".
detectIssue: **PROPOSAL** — `anti_extension` dominant → `low_back_pain` confirm. painToFaultMap
(current): `lower_back`→[anti_extension], `shoulder`→[stable_limbs].

### 5.2 `bird_dog` — builder ✓, registered ✓, rep-scored, MET 3.5
[bird_dog.dart#L190-193](lib/exercise/1.Bird%20Dog/bird_dog.dart#L190). Copy is internally cued /
duplicated; refine per F3.

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `lumbar_fails_count` | limb raised too high, back over-extends | Nâng tay chân ngang thân thôi, giữ lưng phẳng | Lưng giữ thẳng, rất an toàn |
| `alignment_fails_count` | neck cranes / limbs not long | Vươn dài tay chân, mắt nhìn xuống sàn | Vươn dài chuẩn, cổ trung tính |
| `trunk_fails_count` | hips/torso wobble | Giữ hông vững như chuông không lắc | Thân cứng cáp, không lắc |
| `tempo_fails_count` | doesn't hold the top | Giữ đủ 5 giây ở đỉnh mỗi nhịp | Giữ đủ nhịp, kiểm soát tốt |

praiseMetricNames: lumbar→"Lưng thẳng", trunk→"Ổn định", tempo→"Nhịp nhàng" (alignment not praised —
fine). detectIssue: **PROPOSAL** — `lumbar` dominant → `low_back_pain` confirm. painToFaultMap
(current): `lower_back`→[lumbar, trunk], `shoulder`→[alignment].

---

## 6. POSTERIOR CHAIN family

### 6.1 `superman` — builder ✓, registered ✓, rep-scored, MET 3.5
[superman.dart#L407-410](lib/exercise/5.Superman/superman.dart#L407). All four keys covered; copy
duplicated (F3).

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `elevation_fails` | one limb drops during hold | Nâng đều cả tay và chân, không để bên nào rơi | Tay chân nâng đều, đẹp |
| `hip_fails` | hips lift off the floor | Giữ hông làm điểm tựa, chỉ nâng tay chân | Hông làm trụ chắc |
| `hold_fails` | doesn't pause at the top | Lên chậm, giữ ở điểm cao nhất lâu hơn | Giữ đỉnh đủ lâu, kiểm soát tốt |
| `lumbar_fails` | over-arches lumbar | Nâng vừa sức để thắt lưng không uốn quá gắt | Lưng uốn vừa phải, an toàn |

praiseMetricNames: elevation→"Độ nâng tay chân", hold→"Thời gian giữ", lumbar→"An toàn lưng".
detectIssue: **PROPOSAL** — `lumbar` dominant → `low_back_pain` confirm. painToFaultMap (current):
`lower_back`→[lumbar_fails, hip_fails], `shoulder`→[elevation_fails].

---

## 7. "EXISTING" family (brief's label; actual status varies)

### 7.1 `curl_up` — **NO builder, BUILD THIS** — rep-scored, MET propose 3.5
Keys ready, [curl_up.dart#L310-312](lib/exercise/curl_up/curl_up.dart#L310); `max_rep` pushed (L319).
Semantics from the metric files (thresholds noted).

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `trunk_elev_fails_count` | peak elevation >45° → it became a full sit-up (lumbar load) | Cuộn nhỏ thôi, chỉ nhấc bả vai khỏi sàn | Giữ tầm cuộn nhỏ, đúng cơ bụng |
| `neck_pull_fails_count` | chin pulls to chest >15° | Giữ một quả bóng tưởng tượng dưới cằm | Cổ trung tính, không kéo đầu |
| `knee_ext_fails_count` | knees straighten from ~90° baseline | Giữ bàn chân phẳng, ấn gót, gối gập đều | Gối giữ đúng góc, ổn định |

praiseMetricNames (propose): trunk_elev→"Biên độ cuộn", neck_pull→"Cổ trung tính", knee_ext→"Gối".
detectIssue: **PROPOSAL** — `neck_pull` dominant → `neck` self-report "Cổ có căng khi cuộn lên
không?"; `trunk_elev` dominant → `low_back_pain` confirm. painToFaultMap (propose): `neck`→[neck_pull_fails_count],
`lower_back`→[trunk_elev_fails_count]. isSecondBased: false.

### 7.2 `glute_bridge` — **NO builder + BLOCKED** — rep-scored, MET propose 3.5
`onSetComplete(){}` is **empty** ([glute_bridge.dart#L231](lib/exercise/glute%20bridge/glute_bridge.dart#L231)).
**No fault keys, no `max_rep`, no `good_rep_count` are emitted.** I did not invent keys.

Available metric classes (would need wiring before a builder can key on them):
`HipExtension`, `KneeAngle`, `NeckHead`, `SpeedControl`
([glute bridge/metrics/](lib/exercise/glute%20bridge/metrics/)). *Candidate* key names if/when
`onSetComplete` is wired (NOT emitted today, do not use as-is): e.g. `hip_extension_fails_count`,
`knee_angle_fails_count`, `neck_head_fails_count`, `speed_fails_count`. **PASS-2 prerequisite:** wire
`onSetComplete()` to push these + `max_rep` + `pushGoodRepCount()`, mirroring squat. Until then,
flagged and parked.

### 7.3 `push_up` — **NO builder, BUILD THIS** — rep-scored, MET propose 3.8
Keys ready, [push_up.dart#L210-212](lib/exercise/push%20up/push_up.dart#L210); `max_rep` pushed (L225).

| fault key (exact) | what it detects | proposed VN tip (idea) | proposed VN praise |
|---|---|---|---|
| `trunk_alignment_fails_count` | hips sag or pike, body not a line | Siết mông và bụng, giữ một đường thẳng từ đầu tới gót | Thân thẳng một đường, rất chắc |
| `depth_fails_count` | not low enough (elbow ~<90°) | Hạ ngực xuống tới khi cùi chỏ gập ~90° | Xuống đủ sâu, biên độ tốt |
| `tempo_fails_count` | drops too fast, no control | Hạ người trong ~2 giây, đừng buông rơi | Hạ có kiểm soát, đẹp |

praiseMetricNames (propose): trunk_alignment→"Trục thân", depth→"Độ sâu", tempo→"Nhịp".
detectIssue: **PROPOSAL** — `depth` dominant → `shoulder` self-report "Vai có đau khi đẩy không?";
`trunk_alignment` dominant → `low_back_pain` confirm. painToFaultMap (propose): `lower_back`→[trunk_alignment_fails_count],
`shoulder`→[depth_fails_count], `wrist`→[trunk_alignment_fails_count]. isSecondBased: false. Register
under id `push_up`.

### 7.4 `plank` — builder ✓, registered ✓, `isSecondBased` true, MET 3.5 — already clean
[plank.dart#L128-130](lib/exercise/plank/plank.dart#L128). Reference-quality builder (distinct
watch/next, external cues, full praise maps). No changes needed beyond the F2 vocab decision.

| fault key (exact) | what it detects | current VN tip (keep) | current VN praise |
|---|---|---|---|
| `trunk_fails_count` | hip out of line (sag/pike) | watch: "Giữ hông nằm trên một đường thẳng với vai và cổ chân." / next: "Ép nhẹ khuỷu tay xuống sàn và siết bụng trước khi giữ." | "Trục thân ổn định trong c/t giây." |
| `neck_fails_count` | head/neck out of line | next: "Nhìn xuống sàn, giữ gáy dài thay vì ngẩng hoặc cúi đầu." | "Cổ vai giữ gọn trong c/t giây." |
| `knee_fails_count` | knees bend, plank too easy | next: "Đẩy gót ra sau để khóa gối và giữ thân người dài." | "Gối giữ thẳng trong c/t giây." |

painToFaultMap (current): `lower_back`→[trunk], `neck`→[neck], `knee`→[knee]. (`neck` is a valid
onboarding id ✓.) detectIssue null (F1).

### 7.5 `lunge` — **NO builder + BLOCKED** — rep-scored, MET propose 4.5
`onSetComplete(){}` **empty** ([lunge.dart#L148](lib/exercise/lunge/lunge.dart#L148)). **No keys
emitted.** Available metric classes: `Depth`, `HeelLift`, `LumbarProxy`, `TrunkLean`
([lunge/metrics/](lib/exercise/lunge/metrics/)). Candidate key names if wired (NOT emitted):
`depth_fails_count`, `heel_lift_fails_count`, `lumbar_fails_count`, `trunk_lean_fails_count`.
PASS-2 prerequisite: wire `onSetComplete()`. Flagged and parked. (Distinct from `walking_lunge`,
which IS wired and registered.)

### 7.6 `jumping_jack` — **NO builder + BLOCKED** — rep-scored, MET propose 8.0
`onSetComplete(){}` **empty** ([jumping_jack.dart#L158](lib/exercise/jumping%20jack/jumping_jack.dart#L158)).
**No keys emitted.** Available metric classes: `Tempo`, `LegSpread`, `ArmExtension`
([jumping jack/metrics/](lib/exercise/jumping%20jack/metrics/)). Candidate key names if wired (NOT
emitted): `tempo_fails_count`, `leg_spread_fails_count`, `arm_extension_fails_count`. PASS-2
prerequisite: wire `onSetComplete()`. Flagged and parked.

### 7.7 `warrior_one` — builder ✓, registered ✓, `isSecondBased` true, MET 3.0 — already clean
[warrior_one.dart#L198-202](lib/exercise/warrior_1/warrior_one.dart#L198). Reference-quality (distinct
watch/next, `criticalMetrics`, full praise). Pain keys all valid onboarding ids.

| fault key (exact) | what it detects | current VN tip (keep) | praise label |
|---|---|---|---|
| `trunk_lean_fails_count` | torso leans too far (lost upright) | "Ấn bàn chân sau xuống sàn và kéo thân người cao lên..." | Trục thân |
| `cervical_fails_count` | neck cranes back/tucks | "Nhìn thẳng theo thân người, giữ gáy dài và mềm." | Cổ vai |
| `arm_fails_count` | arms don't reach steadily | "Vươn tay lên cao vừa sức, giữ khuỷu tay mềm..." | Tay |
| `back_knee_fails_count` | back knee over-bends | "Đẩy gót sau ra xa và giữ chân sau dài hơn." | Chân sau |
| `back_straight_fails_count` | hips rotate / back compensates | "Thu nhẹ xương sườn, giữ hông nhìn về trước..." | Hông lưng |

criticalMetrics: trunk_lean, back_straight. painToFaultMap (current, all valid):
`lower_back`→[trunk_lean, back_straight], `neck`→[cervical], `shoulder`→[arm], `knee`→[back_knee].
detectIssue null (F1).

---

## 8. FLAGS

**Fault keys unfindable (do not build until wired):**
- `glute_bridge` — `onSetComplete(){}` empty; metrics exist (HipExtension/KneeAngle/NeckHead/SpeedControl) but emit nothing.
- `lunge` — `onSetComplete(){}` empty; metrics exist (Depth/HeelLift/LumbarProxy/TrunkLean).
- `jumping_jack` — `onSetComplete(){}` empty; metrics exist (Tempo/LegSpread/ArmExtension).

**Score-killing bugs (rep score = 0 until fixed):**
- `leg_raise` — never pushes `max_rep`.
- `plank_shoulder_tap` — never pushes `max_rep` (and not registered).

**Interpreter / detectIssue:**
- No interpreter exists for any of the 19 (only `SquatInterpreter`). All 14 existing `detectIssue()`
  return null. Every detectIssue confirmation question in this doc is a PROPOSAL needing a new
  interpreter or inline logic + clinical sign-off (Nam). `interpretingMap` has no non-squat measured
  issues to map.

**Pain-vocabulary conflict (HIGH IMPACT — Nam to pick canonical set):**
- Three vocabularies, no normalizer (F2). Existing builders key `lower_back`/`shoulder`, but
  onboarding S04 persists `back`/`neck` — so most current pain links likely never fire.
- `v_up` keys `hamstring` — in no vocabulary; dead. Proposed fix above re-keys to `knee`.
- The brief's stated vocab (`ankle, lower_back, knee, hip, shoulder, neck, other`) matches the
  interpreter/Progress side, not the onboarding S04 side (`back, neck, knee, hip, wrist, other`).

**`isSecondBased` surprises (not bugs, just broader than brief):**
- `plank` and `warrior_one` are also `isSecondBased: true` holds (4 total, not 2).

**Cleanups:**
- `bear_plank` emits both `_fails` and `_fails_count` variants of knee/back/weight → double-counts in
  the aggregate. Builder keys the non-`_count` variant; drop the duplicates.
- Tip gaps (emitted fault with no `faultToTipMap` entry): `plank_shoulder_tap` (`tempo_fails`),
  `v_up` (`knee_fails_count`, `tempo_fails_count`), `reverse_crunch` (`arm_position_fails`),
  `leg_raise` (`rom_fails_count`, `arm_position_fails_count`), `dead_bug` (`floor_contact_fails_count`).
- watch==next duplication + internal cueing across most builders (F3); `plank` / `warrior_one` are
  the in-repo good templates.

**MET proposals (no class/registry value existed):** `curl_up` 3.5, `push_up` 3.8, `glute_bridge`
3.5 (matches commented-out value), `lunge` 4.5, `jumping_jack` 8.0. `mountain_climber` 8.0,
`plank_shoulder_tap` 3.5 (these two have builders, just need a registry `met`).

**Registry ids verified** ([exercise_definition.dart](lib/models/exercise_definition.dart)):
`lunge`, `jumping_jack`, `push_up`, `glute_bridge`, `curl_up`. Verify `mountain_climber` /
`plank_shoulder_tap` definition ids before adding registry entries (their builder files exist;
`resolveReportBuilder` also normalizes keys).
