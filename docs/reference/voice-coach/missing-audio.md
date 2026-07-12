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

Writing NEW lines (or reviewing pending ones): follow `.agents/skills/voice-copy/SKILL.md` —
cue formula (external target + no-assumption fence), grounding steps, per-slot templates
(decisions.md 07-11 "Voice-copy skill"). Pending un-recorded lines below predate the formula;
check them against it before recording.

## Rep fleet Tier 1 gaps (07-11 code sync)

Tier 1 reuses the resolver convention `assets/audio/<slug>/<fault_id>.mp3`; it did not add or rename
audio. Two implemented detector groups currently resolve to safe no-ops:

| Exercise | Implemented fault ids with no resolving MP3 | Why |
|---|---|---|
| Squat | `heel`, `depth`, `trunk`, `tempo`, `sync` | The old Squat stack used differently named WAV files. The generic resolver has no aliases for those fault keys. |
| Ashtanga Namaskara | `hip`, `neck` | `assets/audio/ashtanga_namaskara/` contains no matching recordings. |

One implemented Russian Twist detector, `arm_swinging`, remains intentionally outside the script: no
legacy id or audio meaning matches it closely enough. Bird Dog's `MissingBody` / `Plank` guard records
also remain unmapped; its rejected `opposite_side`, `alternate`, and `hold` attempts are cleared before
the policy adapter can speak them. Tricep Dip has recordings for its declared faults, but its metric
objects are not driven by the exercise, so those recordings are unreachable until detector wiring is
designed separately.

Existing recordings with no implemented/reachable fault are orphaned for now:

| Exercise | Orphaned legacy ids |
|---|---|
| Push Up | `pike`, `setup_guard` |
| Wall Push Up | `setup` |
| Lunge | `too_deep` |
| Walking Lunge | `front_knee`, `framing` |
| Jump Squat | `too_fast` |
| Standing Knee-to-Elbow | `cross_rom`, `setup` |
| Tricep Dip | `setup`; all four fault recordings are detector-unreachable |
| Sit-Up | `tempo` (data only; no FaultRecord) |
| Mountain Climber | `double_knee` |
| Russian Twist | `spine`, `thoracic` |
| Jumping Jack | `tempo_slow` |
| Ashtanga Namaskara | `knees`, `chest`, `count_guard` |
| Plank Up-Down | `knee` |

Exercises not listed have no known orphaned fault id in their current script. The full per-fault
decision surface lives in `voice-fleet-tier1-review.html`.

## MASTER RECORD LIST (07-11) — every file to create, one flat table

Everything the fleet needs, in one place: legacy re-records (old files predate the persona
convention), the new soft lines, and the optional reminders. Supersedes the two earlier
checklists ("Missing CRITICAL lines" + "Fleet Tier-1 SOFT cues"), whose wordings are folded in.
Glute Bridge and all `common.*` files are DONE to convention — not listed.

Lines POLISHED 07-11 to the §3d copywriting craft (voice-research-rules.md): external-focus
phrasing where it fits (verb + direction + concrete target — "đạp sàn" over "duỗi gối"), one
verb + one target, positive/target framing (never "đừng"), `nhé` softening. Still DRAFTS — your
recording is canonical. Pronoun stays `bạn` per the persona convention; §3d flags `bạn` may read
"customer-service bot" to older users (age-matched anh/chị/em is the natural PT register) — an
open call for you, deliberately not changed here.

How to use:
- Drop each file at EXACTLY the path shown (paths are what the resolver loads today; note the
  odd legacy names called out inline). Replacing an existing file at the same path is the upgrade.
- A missing file is a safe logged no-op — partial batches are fine, record in any order.
- Status: **re-record** = legacy file exists, content/tone predates the persona rules · **NEW** =
  no file exists · **soft** = new `_soft` nudge line · **reminder (opt.)** = next-rep reminder,
  record only the ones you want coached (empty = silent; glute precedent is 1-2 per exercise).
- Patterns: critical `Bạn [action] nhé.` · soft `Tốt, bạn [action] chút nữa là đẹp.` · reminder
  `Lần này bạn nhớ [action] nhé.`

| # | File (assets/audio/…) | Draft line | Status |
|---|---|---|---|
| 1 | squat/squat.setup_position.mp3 | Bạn đứng hai chân rộng bằng vai, quay nghiêng với màn hình nhé. | NEW |
| 2 | squat/squat.active_intro.mp3 | Ngồi xuống chậm rồi đứng thẳng lên, đều nhịp nhé. | NEW |
| 3 | squat/heel.mp3 | Bạn đạp gót chân xuống sàn nhé. | NEW (legacy WAV nho_giu_got_chan — listen; rename if it fits) |
| 4 | squat/depth.mp3 | Bạn ngồi xuống thấp hơn nhé. | NEW (legacy nho_xuong_thap_hon) |
| 5 | squat/trunk.mp3 | Bạn hướng ngực lên, giữ lưng thẳng nhé. | NEW (legacy uon_nguc_len) |
| 6 | squat/tempo.mp3 | Bạn hạ người xuống thật chậm nhé. | NEW (legacy nho_cham_lai) |
| 7 | squat/sync.mp3 | Bạn đẩy hông và ngực lên cùng lúc nhé. | NEW |
| 8 | squat/heel_reminder.mp3 | Lần này bạn nhớ đạp gót xuống sàn nhé. | reminder (opt.) |
| 9 | squat/depth_reminder.mp3 | Lần này bạn nhớ ngồi xuống thấp hơn nhé. | reminder (opt.) |
| 10 | push_up/push_up.setup_position.mp3 | Bạn vào tư thế hít đất, hai tay rộng bằng vai nhé. | re-record |
| 11 | push_up/push_up.active_intro.mp3 | Hạ ngực xuống sàn rồi đẩy người lên nhé. | re-record |
| 12 | push_up/depth.mp3 | Bạn hạ ngực gần sàn hơn nhé. | re-record |
| 13 | push_up/tempo.mp3 | Bạn hạ người xuống thật chậm nhé. | re-record |
| 14 | push_up/sag.mp3 | Bạn siết bụng, giữ người thành một đường thẳng nhé. | re-record |
| 15 | push_up/depth_soft.mp3 | Tốt, bạn hạ ngực gần sàn hơn chút nữa là đẹp. | soft |
| 16 | push_up/sag_reminder.mp3 | Lần này bạn nhớ siết bụng, giữ người thẳng nhé. | reminder (opt.) |
| 17 | wall_push_up/wall_push_up.setup_position.mp3 | Bạn đứng cách tường một sải tay, hai tay chống lên tường nhé. | re-record |
| 18 | wall_push_up/wall_push_up.active_intro.mp3 | Đưa ngực về phía tường rồi đẩy người ra nhé. | re-record |
| 19 | wall_push_up/body_line.mp3 | Bạn siết bụng, giữ người thành một đường thẳng nhé. | re-record |
| 20 | wall_push_up/foot.mp3 | Bạn giữ chân đứng yên một chỗ nhé. | re-record |
| 21 | wall_push_up/heel.mp3 | Bạn giữ gót chân chạm sàn nhé. | re-record |
| 22 | wall_push_up/shoulder.mp3 | Bạn thả lỏng vai xuống nhé. | re-record |
| 23 | wall_push_up/elbow.mp3 | Bạn khép khuỷu tay vào gần người nhé. | re-record |
| 24 | wall_push_up/hand.mp3 | Bạn chống tay chắc lên tường nhé. | re-record |
| 25 | wall_push_up/body_line_soft.mp3 | Tốt, bạn siết bụng giữ người thẳng hơn chút nữa là đẹp. | soft |
| 26 | wall_push_up/foot_soft.mp3 | Tốt, bạn giữ chân đứng yên là đẹp. | soft |
| 27 | wall_push_up/shoulder_soft.mp3 | Tốt, bạn thả vai xuống chút nữa là đẹp. | soft |
| 28 | wall_push_up/elbow_soft.mp3 | Tốt, bạn khép khuỷu tay vào chút nữa là đẹp. | soft |
| 29 | wall_push_up/head_soft.mp3 | Tốt, bạn giữ đầu thẳng hơn chút nữa là đẹp. | soft |
| 30 | wall_push_up/cervical_soft.mp3 | Tốt, bạn thu cằm lại chút nữa là đẹp. | soft |
| 31 | wall_push_up/tempo_soft.mp3 | Tốt, bạn hạ người chậm hơn chút nữa là đẹp. | soft |
| 32 | wall_push_up/body_line_reminder.mp3 | Lần này bạn nhớ giữ người thẳng nhé. | reminder (opt.) |
| 33 | lunge/lunge.setup_position.mp3 | Bạn đứng thẳng, một chân bước dài lên trước nhé. | re-record |
| 34 | lunge/lunge.active_intro.mp3 | Hạ gối sau xuống gần sàn rồi đứng lên nhé. | re-record |
| 35 | lunge/depth.mp3 | Bạn hạ gối sau xuống gần sàn hơn nhé. | re-record |
| 36 | lunge/trunk.mp3 | Bạn hướng ngực lên, giữ lưng thẳng nhé. | re-record |
| 37 | lunge/lumbar.mp3 | Bạn siết bụng lại nhé. | re-record |
| 38 | lunge/heel.mp3 | Bạn đạp gót chân trước xuống sàn nhé. | re-record |
| 39 | lunge/depth_reminder.mp3 | Lần này bạn nhớ hạ gối sâu hơn nhé. | reminder (opt.) |
| 40 | walking_lunge/setup_position.mp3 | Bạn đứng thẳng, chuẩn bị bước dài về trước nhé. | re-record |
| 41 | walking_lunge/active_intro.mp3 | Bước tới, hạ gối sau xuống, giữ một nhịp rồi bước tiếp nhé. | re-record |
| 42 | walking_lunge/hold.mp3 | Bạn giữ ở dưới thêm một nhịp nhé. | re-record |
| 43 | walking_lunge/torso.mp3 | Bạn giữ thân trên thẳng nhé. | re-record (critical since 07-11 flip) |
| 44 | walking_lunge/rear_depth_soft.mp3 | Tốt, bạn hạ gối sau gần sàn hơn chút nữa là đẹp. | soft |
| 45 | walking_lunge/step_length_soft.mp3 | Tốt, bạn giữ sải bước đều hơn chút nữa là đẹp. | soft |
| 46 | walking_lunge/torso_reminder.mp3 | Lần này bạn nhớ giữ thân thẳng nhé. | reminder (opt.) |
| 47 | cossack_squat/setup_position.mp3 | Bạn đứng hai chân rộng hơn vai nhé. | re-record |
| 48 | cossack_squat/active_intro.mp3 | Ngồi xuống một bên, chân kia duỗi thẳng, rồi đổi bên nhé. | re-record |
| 49 | cossack_squat/knee_valgus.mp3 | Bạn hướng đầu gối theo mũi chân nhé. | re-record |
| 50 | cossack_squat/heel.mp3 | Bạn đạp gót chân xuống sàn nhé. | re-record |
| 51 | cossack_squat/depth_shallow.mp3 | Bạn ngồi xuống thấp hơn nhé. | re-record |
| 52 | cossack_squat/straight_leg.mp3 | Bạn duỗi thẳng chân bên kia nhé. | re-record |
| 53 | cossack_squat/depth_deep_soft.mp3 | Tốt, bạn ngồi vừa tầm thôi là đẹp. | soft |
| 54 | cossack_squat/torso_soft.mp3 | Tốt, bạn hướng ngực lên chút nữa là đẹp. | soft |
| 55 | cossack_squat/knee_valgus_reminder.mp3 | Lần này bạn nhớ hướng gối theo mũi chân nhé. | reminder (opt.) |
| 56 | jump_squat/set_up position.mp3 | Bạn đứng hai chân rộng bằng vai nhé. | re-record (KEEP this exact odd filename — resolver special-case) |
| 57 | jump_squat/active_intro.mp3 | Ngồi xuống rồi bật lên, tiếp đất thật nhẹ nhé. | re-record |
| 58 | jump_squat/landing_stiff.mp3 | Bạn tiếp đất nhẹ, trùng gối để giảm sốc nhé. | re-record |
| 59 | jump_squat/trunk.mp3 | Bạn giữ lưng thẳng nhé. | re-record |
| 60 | jump_squat/takeoff_depth.mp3 | Bạn ngồi xuống thấp hơn trước khi bật nhé. | re-record |
| 61 | jump_squat/landing_depth_soft.mp3 | Tốt, lúc tiếp đất bạn trùng gối thêm chút nữa là đẹp. | soft |
| 62 | standing_kte/setup_position.mp3 | Bạn đứng thẳng, hai tay đưa lên cao nhé. | re-record |
| 63 | standing_kte/active_intro.mp3 | Kéo gối lên chạm khuỷu tay đối diện nhé. | re-record |
| 64 | standing_kte/core_drive.mp3 | Bạn siết bụng kéo gối lên cao nhé. | re-record |
| 65 | standing_kte/knee_valgus.mp3 | Bạn hướng đầu gối theo mũi chân nhé. | re-record |
| 66 | standing_kte/pelvic_drop.mp3 | Bạn giữ hông ngang bằng nhé. | re-record |
| 67 | tricep_dip/setup_position.mp3 | Bạn ngồi trên sàn, hai tay chống phía sau nhé. | re-record (intros only — fault detectors not wired) |
| 68 | tricep_dip/active_intro.mp3 | Hạ người xuống rồi đẩy thẳng tay lên nhé. | re-record |
| 69 | step_back_burpee/setup_position.mp3 | Bạn đứng thẳng, chuẩn bị nhé. | re-record |
| 70 | step_back_burpee/active_intro.mp3 | Chống tay, bước chân ra sau thành plank, rồi thu về đứng lên nhé. | re-record |
| 71 | step_back_burpee/squat_hinge.mp3 | Bạn ngồi xổm xuống, giữ lưng thẳng nhé. | re-record |
| 72 | step_back_burpee/plank_sag.mp3 | Bạn siết bụng, giữ người thẳng khi plank nhé. | re-record |
| 73 | step_back_burpee/squat_depth_soft.mp3 | Tốt, bạn hạ hông thấp hơn chút nữa là đẹp. | soft |
| 74 | step_back_burpee/plank_extension_soft.mp3 | Tốt, bạn duỗi chân thẳng hơn chút nữa là đẹp. | soft |
| 75 | mc_gill_curl_up/curl_up.setup_position.mp3 | Bạn nằm ngửa, một chân co một chân duỗi, tay đặt dưới lưng nhé. | re-record |
| 76 | mc_gill_curl_up/curl_up.active_intro.mp3 | Nâng nhẹ đầu và vai lên, giữ một nhịp rồi hạ xuống nhé. | re-record |
| 77 | mc_gill_curl_up/knee_extension.mp3 | Bạn giữ gối co đúng tư thế nhé. | re-record |
| 78 | mc_gill_curl_up/neck_pull.mp3 | Bạn thả lỏng cổ nhé. | re-record |
| 79 | mc_gill_curl_up/trunk_high.mp3 | Bạn nâng đầu và vai lên nhẹ thôi nhé. | re-record |
| 80 | mc_gill_curl_up/knee_extension_soft.mp3 | Tốt, bạn giữ gối co thêm chút nữa là đẹp. | soft |
| 81 | mc_gill_curl_up/neck_pull_soft.mp3 | Tốt, bạn thả lỏng cổ chút nữa là đẹp. | soft |
| 82 | mc_gill_curl_up/trunk_high_soft.mp3 | Tốt, bạn nâng vai nhẹ thôi là đẹp. | soft |
| 83 | mc_gill_curl_up/trunk_low_soft.mp3 | Tốt, bạn nâng vai lên cao hơn chút nữa là đẹp. | soft |
| 84 | sit_up/sit_up.setup_position.mp3 | Bạn nằm ngửa, co gối, tay đặt sau đầu nhé. | re-record |
| 85 | sit_up/sit_up.active_intro.mp3 | Ngồi dậy bằng cơ bụng rồi hạ xuống chậm nhé. | re-record |
| 86 | sit_up/jerking.mp3 | Bạn ngồi dậy đều bằng cơ bụng nhé. | re-record |
| 87 | sit_up/rom.mp3 | Bạn ngồi dậy cao hơn nhé. | re-record |
| 88 | sit_up/stability.mp3 | Bạn lên xuống đều, giữ người ổn định nhé. | re-record |
| 89 | sit_up/jerking_reminder.mp3 | Lần này bạn nhớ lên đều bằng cơ bụng nhé. | reminder (opt.) |
| 90 | v_up/v_up.setup_position.mp3 | Bạn nằm ngửa, tay duỗi qua đầu nhé. | re-record |
| 91 | v_up/v_up.active_intro.mp3 | Nâng tay và chân lên chạm nhau thành chữ V rồi hạ xuống nhé. | re-record |
| 92 | v_up/tempo.mp3 | Bạn nâng và hạ người thật chậm nhé. | re-record |
| 93 | v_up/jerking.mp3 | Bạn nâng người đều bằng cơ bụng nhé. | re-record |
| 94 | v_up/knee.mp3 | Bạn giữ chân thẳng gối nhé. | re-record |
| 95 | v_up/sync_soft.mp3 | Tốt, bạn nâng tay và chân cùng lúc là đẹp. | soft |
| 96 | v_up/rom_soft.mp3 | Tốt, bạn nâng người cao hơn chút nữa là đẹp. | soft |
| 97 | dead_bug/dead_bug.setup_position.mp3 | Bạn nằm ngửa, tay hướng lên trần, gối co vuông góc nhé. | re-record |
| 98 | dead_bug/dead_bug.active_intro.mp3 | Duỗi tay và chân đối diện ra chậm rồi thu về nhé. | re-record |
| 99 | dead_bug/opposite_side.mp3 | Bạn duỗi tay và chân đối diện nhau nhé. | re-record |
| 100 | dead_bug/alternate.mp3 | Bạn đổi bên luân phiên nhé. | re-record |
| 101 | dead_bug/anti_extension.mp3 | Bạn ép lưng dưới sát sàn nhé. | re-record |
| 102 | dead_bug/floor_contact.mp3 | Bạn giữ tay và chân trên không nhé. | re-record |
| 103 | dead_bug/stable_limbs.mp3 | Bạn giữ tay chân bên kia cố định nhé. | re-record |
| 104 | dead_bug/tempo.mp3 | Bạn duỗi ra thật chậm nhé. | re-record |
| 105 | dead_bug/anti_extension_reminder.mp3 | Lần này bạn nhớ ép lưng sát sàn nhé. | reminder (opt.) |
| 106 | bird_dog/bird_dog.setup_position.mp3 | Bạn quỳ chống tay, tay dưới vai, gối dưới hông nhé. | re-record |
| 107 | bird_dog/bird_dog.active_intro.mp3 | Duỗi tay và chân đối diện ra, giữ một nhịp rồi thu về nhé. | re-record |
| 108 | bird_dog/alignment.mp3 | Bạn duỗi tay chân thẳng hàng với lưng nhé. | re-record |
| 109 | bird_dog/head.mp3 | Bạn giữ đầu thẳng, mắt nhìn xuống sàn nhé. | re-record |
| 110 | bird_dog/lumbar.mp3 | Bạn siết bụng, giữ lưng cố định nhé. | re-record |
| 111 | bird_dog/trunk.mp3 | Bạn giữ hông ngang bằng, thân vững nhé. | re-record |
| 112 | bird_dog/lumbar_reminder.mp3 | Lần này bạn nhớ siết bụng, giữ lưng yên nhé. | reminder (opt.) |
| 113 | superman/superman.setup_position.mp3 | Bạn nằm sấp, tay duỗi về phía trước nhé. | re-record |
| 114 | superman/superman.active_intro.mp3 | Nâng tay và chân lên, giữ một nhịp rồi hạ xuống nhé. | re-record |
| 115 | superman/hip.mp3 | Bạn giữ hông chạm sàn nhé. | re-record |
| 116 | superman/elevation_arm.mp3 | Bạn vươn tay lên cao hơn nhé. | re-record |
| 117 | superman/elevation_leg.mp3 | Bạn nâng chân lên cao hơn nhé. | re-record |
| 118 | superman/lumbar.mp3 | Bạn nâng người lên vừa phải thôi nhé. | re-record |
| 119 | superman/hold.mp3 | Bạn giữ tư thế thêm một nhịp nhé. | re-record |
| 120 | mountain_climber/mountain_climber.setup_position.mp3 | Bạn vào tư thế plank cao, tay thẳng nhé. | re-record |
| 121 | mountain_climber/mountain_climber.active_intro.mp3 | Kéo từng gối lên gần ngực, đổi chân thật nhanh nhé. | re-record |
| 122 | mountain_climber/rom.mp3 | Bạn kéo gối lên gần ngực hơn nhé. | re-record |
| 123 | mountain_climber/trunk_sag.mp3 | Bạn siết bụng, giữ hông ngang bằng nhé. | re-record |
| 124 | mountain_climber/trunk_bounce.mp3 | Bạn giữ hông ổn định nhé. | re-record |
| 125 | mountain_climber/trunk_sag_reminder.mp3 | Lần này bạn nhớ giữ hông ngang bằng nhé. | reminder (opt.) |
| 126 | reverse_crunch/reverse_crunch.setup_position.mp3 | Bạn nằm ngửa, co gối, tay xuôi theo người nhé. | re-record |
| 127 | reverse_crunch/reverse_crunch.active_intro.mp3 | Cuộn hông lên khỏi sàn rồi hạ xuống chậm nhé. | re-record |
| 128 | reverse_crunch/curl.mp3 | Bạn cuộn hông lên khỏi sàn nhé. | re-record |
| 129 | reverse_crunch/arms.mp3 | Bạn giữ tay xuôi trên sàn nhé. | re-record |
| 130 | reverse_crunch/tempo_soft.mp3 | Tốt, bạn hạ hông xuống chậm hơn chút nữa là đẹp. | soft |
| 131 | reverse_crunch/momentum_soft.mp3 | Tốt, bạn cuộn hông chủ động hơn chút nữa là đẹp. | soft |
| 132 | plank_shoulder_tap/plank_shoulder_tap.setup_position.mp3 | Bạn vào tư thế plank cao nhé. | re-record |
| 133 | plank_shoulder_tap/plank_shoulder_tap.active_intro.mp3 | Lần lượt chạm tay lên vai đối diện, giữ hông vững nhé. | re-record |
| 134 | plank_shoulder_tap/hip_rotation.mp3 | Bạn giữ hông ngang bằng nhé. | re-record |
| 135 | plank_shoulder_tap/tap.mp3 | Bạn chạm tay lên vai đối diện nhé. | re-record |
| 136 | plank_shoulder_tap/trunk.mp3 | Bạn siết bụng, giữ người thẳng nhé. | re-record |
| 137 | plank_shoulder_tap/tempo_soft.mp3 | Tốt, bạn chạm vai chậm hơn chút nữa là đẹp. | soft |
| 138 | plank_shoulder_tap/hip_rotation_reminder.mp3 | Lần này bạn nhớ giữ hông ngang bằng nhé. | reminder (opt.) |
| 139 | leg_raises/leg_raises.setup_position.mp3 | Bạn nằm ngửa, chân duỗi thẳng, tay xuôi theo người nhé. | re-record |
| 140 | leg_raises/leg_raises.active_intro.mp3 | Nâng hai chân lên cao rồi hạ xuống thật chậm nhé. | re-record |
| 141 | leg_raises/pelvic.mp3 | Bạn ép lưng dưới sát sàn nhé. | re-record |
| 142 | leg_raises/rom.mp3 | Bạn nâng chân lên cao hơn nhé. | re-record |
| 143 | leg_raises/knee.mp3 | Bạn giữ chân thẳng gối nhé. | re-record |
| 144 | leg_raises/tempo.mp3 | Bạn hạ chân xuống thật chậm nhé. | re-record |
| 145 | leg_raises/arms.mp3 | Bạn giữ tay xuôi trên sàn nhé. | re-record |
| 146 | leg_raises/pelvic_reminder.mp3 | Lần này bạn nhớ ép lưng sát sàn nhé. | reminder (opt.) |
| 147 | russian_twist/setup_position.mp3 | Bạn ngồi, co gối, ngả người ra sau một chút nhé. | re-record |
| 148 | russian_twist/active_intro.mp3 | Xoay người sang hai bên luân phiên nhé. | re-record |
| 149 | russian_twist/knee.mp3 | Bạn giữ gối ổn định nhé. | re-record |
| 150 | russian_twist/too_upright.mp3 | Bạn ngả người ra sau thêm chút nhé. | re-record |
| 151 | russian_twist/too_low.mp3 | Bạn nâng người lên cao hơn chút nhé. | re-record |
| 152 | jumping_jack/jumping_jack.setup_position.mp3 | Bạn đứng thẳng, tay xuôi theo người nhé. | re-record |
| 153 | jumping_jack/jumping_jack.active_intro.mp3 | Bật dạng chân, vung tay lên cao, rồi thu về nhé. | re-record |
| 154 | jumping_jack/arms.mp3 | Bạn vung tay lên cao qua đầu nhé. | re-record |
| 155 | jumping_jack/legs.mp3 | Bạn bật dạng chân rộng hơn nhé. | re-record |
| 156 | jumping_jack/tempo_fast_soft.mp3 | Tốt, bạn giữ nhịp chậm hơn chút nữa là đẹp. | soft |
| 157 | ashtanga_namaskara/ashtanga_namaskara.setup_position.mp3 | Bạn quỳ xuống, chuẩn bị hạ ngực và cằm nhé. | NEW |
| 158 | ashtanga_namaskara/ashtanga_namaskara.active_intro.mp3 | Hạ gối, ngực và cằm chạm sàn, giữ hông cao nhé. | NEW |
| 159 | ashtanga_namaskara/hip.mp3 | Bạn giữ hông cao lên nhé. | NEW |
| 160 | ashtanga_namaskara/neck_soft.mp3 | Tốt, bạn giữ cổ thẳng tự nhiên là đẹp. | soft |
| 161 | plank_up_down/plank_up_down.setup_position.mp3 | Bạn vào tư thế plank thấp trên cẳng tay nhé. | re-record |
| 162 | plank_up_down/plank_up_down.active_intro.mp3 | Lần lượt chống tay lên plank cao rồi hạ về cẳng tay nhé. | re-record |
| 163 | plank_up_down/hip_rotation.mp3 | Bạn giữ hông ngang bằng nhé. | re-record |
| 164 | plank_up_down/trunk.mp3 | Bạn siết bụng, giữ người thẳng nhé. | re-record |
| 165 | plank_up_down/arm_extension.mp3 | Bạn chống thẳng tay khi lên nhé. | re-record |
| 166 | plank_up_down/trunk_reminder.mp3 | Lần này bạn nhớ giữ người thẳng nhé. | reminder (opt.) |

### DO NOT record (unreachable / unmapped — waste of a take)

- Tricep Dip fault lines + softs (`hip_thrust`, `shrug`, `rom`, `extension`) — detectors never
  driven; Tier-3 wiring first. Intros (rows 67-68) still needed.
- Bird Dog `opposite_side` / `alternate` / `hold` — cleared on rejected attempts before the
  adapter can speak them; `MissingBody` / `Plank` — unmapped guard records.
- Russian Twist `arm_swinging` (unmapped) and `rom` (rejected half-twist writes no RepLog).

### Legacy files you can IGNORE (not spoken by the new system)

The critical `<id>.mp3` of always-soft faults never plays — their only voice surface is the
`_soft` file above: wall_push_up head/cervical/tempo · jump_squat landing_depth · curl_up
trunk_low · v_up sync/rom · reverse_crunch tempo/momentum · plank_shoulder_tap tempo ·
jumping_jack tempo_fast · plank_up_down alternating · step_back_burpee squat_depth/
plank_extension · cossack_squat depth_deep/torso · walking_lunge rear_depth/step_length.
Also ignorable: all legacy `good_clean` / `hold_good` / `set_next_*` / `setup_intro` files
(praise is the common pool now; set_next/setup_intro belong to the retired legacy coaches).

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
