# Canonical Numbers (technical)

Single source of numeric truth for Vika's technical values. Never reconstruct numbers from memory,
read here. Update this file first when any number changes. Business/pricing/survey numbers live in
`~/vika-ops/canonical-numbers-business.md`. On conflict, this file wins for technical values; flag and
fix the other doc.

Last reviewed: July 2, 2026.

## Pose Detection Tech
| Spec | Value |
|---|---|
| Pose model | MediaPipe Pose Landmarker Lite |
| Underlying model | BlazePose (via Tasks API) |
| Landmarks | 33 |
| FPS target | ~30 |
| iOS delegate | GPU (Metal) with CPU fallback |
| iOS MediaPipeTasksVision pod | `~> 0.10.21` (current line) |
| Android delegate | CPU (per Phase 1 audit) |
| Android MediaPipe Tasks Vision | `com.google.mediapipe:tasks-vision:0.20230731` (version skew vs iOS, Phase 2 cleanup) |
| iOS sessionPreset | .vga640x480 (Phase 1) |
| iOS minTrackingConfidence (SDK) | 0.7 |
| iOS minPoseDetectionConfidence (SDK) | 0.5 |
| iOS minPosePresenceConfidence (SDK) | 0.5 |
| Android minTrackingConfidence (SDK) | 0.5 (cross-platform inconsistency vs iOS 0.7, cleanup item) |
| BlazePose hip bias | -17.49 deg offset (deprecated by Pose Landmarker) |
| Backend region | Singapore (Supabase) |

## Detection Thresholds
| Threshold | Value | Notes |
|---|---|---|
| formSolid (comparison fallback) | 62 | Min for "form ổn" tier |
| consistencyStreak min | 3 days | Streak fallback tier |
| habitualStrengthThreshold | 0.7 | Praise filter |
| habitualStrengthWindow | 3 sessions | Lookback |
| metricWinThreshold | 0.7 | Metric praise gate |
| Comp gate | compScore <= 1.0 caps below intermediate | Squat |
| Level boundaries | 1.7 / 2.3, RETIRED for home (06-15) | Old home composite boundaries. Home now duration-banded. Yoga uses >=0.75 / >=0.55 on its own 0-1.2 scale. |
| Squat depth weight | 40% | Heaviest feature |
| Training history weight | 25% | Self-report unreliable |
| ExerciseBase.MIN_PRESENCE | 0.7 | Per-landmark presence >= 0.7. Presence = probability landmark exists; stays 0.99+ for legitimately occluded landmarks (back leg in side-view squats). Replaces old MIN_CONFIDENCE post-filter. Confirmed 05-06 PM (empty room 14.7s zero hallucinations + side-view squat presence 0.988+). Channel contract: presence must arrive from native (pose_landmarker_adapter.dart); the adapter's fallback to visibility silently conflates the two if native ever omits it — debug-guarded 2026-07-06 (see decisions.md). |
| ExerciseBase.MIN_VISIBILITY | 0.3 | Per-landmark visibility >= 0.3. Visibility = probability landmark unoccluded given it exists. Noisy (0.34-0.95 on back leg), kept permissive, only rejects fully extrapolated landmarks. ML Kit fallback duplicates likelihood into both fields. |
| ExerciseBase.kDiagnosticMode | false (default) | True ONLY for diagnostic collection. Bypasses auto-pause + pose backpressure. NEVER ship true. |
| PersonDetectorConfig.MIN_PERSON_RATIO (entry) | 0.03 (was 0.5 pre-2a) | Native aggregate ratios distribute lower than old Flutter ML Kit JPEG path. |
| PersonDetectorConfig.MIN_PERSON_RATIO_EXIT | 0.02 (was 0.30 pre-2a) | Sticky by design. Pose empty-landmarks is the canonical missing signal in HYBRID; segmentation is the recheck verifier. |
| PersonDetectorConfig.PIXEL_CONFIDENCE_THRESHOLD | 0.82 (was 0.92 pre-2a) | Per-pixel "is person" hard gate, native side |
| PersonDetectorConfig.SOFT_PIXEL_CONFIDENCE_THRESHOLD | 0.35 (was 0.55 pre-2a) | Soft mask threshold for body coverage when hard mask sparse |
| PersonDetectorConfig.RATIO_SMOOTHING_ALPHA | 0.30 | EMA smoothing for person coverage |
| PersonDetectorConfig.SOFT_RATIO_SCORE_WEIGHT | 0.45 | Soft mask fallback weight in score blend |
| PersonDetectorConfig.SEARCH_PROCESS_INTERVAL | 2000ms | Native segmentation cadence pre-activation |
| PersonDetectorConfig.ACTIVATED_PROCESS_INTERVAL | 8000ms | Cadence post-activation; pose triggers one-shot samples via triggerCheck |
| PersonDetectorConfig.PAUSED_PROCESS_INTERVAL | 1000ms | Cadence while auto-paused (person walked away). Periodic 1s poll re-confirms return ~5x cheaper than the removed per-frame poke (which hit the 200ms cooldown = 5 samples/s); resume ~1.3s. Manual pause stays on the 8s baseline (presence can't clear it). |
| PersonDetectorConfig.REQUEST_SAMPLE_COOLDOWN | 200ms | triggerCheck self-rate-limit |
| HYBRID trigger: pose_low_presence | 0.35 (avg presence absolute, tune from beta) | Fires recheck when frame-level avg presence drops below. Was 0.55 (over-aggressive on push-up close framing). |
| HYBRID trigger: pose_frame_edge | marginX/Y = 4% of image; fires on 2+ landmarks outside OR 5+ at edge (visibleCount >= 8 floor) | Detects landmarks drifting to frame boundary |
| PresenceAnomalyDetector | LONG_WINDOW=60 frames (~2s), SHORT_WINDOW=10 frames (~0.3s), ANOMALY_DELTA=0.15, CONFIRM_FRAMES=3 | Dual-window anomaly on avg presence, self-calibrating per exercise. Confirmed against impl (presence_anomaly_detector.dart defaults). |
| Production flip checklist (before any release commit) | kDiagnosticMode=false AND SEGMENT_REQUEST_FILE_LOG_ENABLED=false | Both bypass/heavy-IO; must be off in prod. |
| Visibility populates on iOS native | Yes, occlusion estimate (0.34-1.00 typical) | Empirical 05-06 PM. Drops to ~0.5 on occluded back-leg. Wrong knob for existence filtering. |
| Presence populates on iOS native | Yes, existence estimate (0.988+ tracked, drops fast when missing) | Empirical 05-06 PM. Right signal for HYBRID trigger + post-filter. |
| Empty-landmarks gate reliability | Confirmed reliable | 05-06 PM: 14.7s empty room, zero hallucinated landmarks. Re-detection ~50ms. Catastrophic gate signal in HYBRID. |
| Presence drop at walkout boundary | 0.99 -> 0.10-0.35 in single frame | Frame 712 of smoke test: leg landmarks cratered while visibility only dropped 0.95->0.7. Presence is the early-warning signal. |

## Squat Anti-Cheat Thresholds (PROVISIONAL, May 27 2026)
| Parameter | Value | Status |
|---|---|---|
| ANGLE_STABLE_GATE (per-exercise FrameBuffer gate) | 2 deg | Provisional, pending home test (was 1.2) |
| ROM_GATE (min descent from baseline before descending) | 36 deg | Tested, confirmed working. Renamed from ROM_GATE_FOR_DES_TO_ASC. |
| ERROR_ALLOW (baseline tolerance) | 2 deg | Provisional (was 5) |
| SQUAT_DESCEND_ANGLE_THRESHOLD | DELETED | Replaced by baseline-relative DepthMetric threshold (baselineAngle - ERROR_ALLOW). |
| Bottom -> ascending transition | Direction-based (isAscendingFrame) | Simplified from ROM gate to single-frame direction check. ANGLE_STABLE_GATE (2) filters noise. |
| Stance width Z-check | DROPPED | Z delta from side view too noisy. Physics ceiling. |
| Walking detection via landmark X-drift | DROPPED | Frame-to-frame X jitter too high. Physics ceiling. |

## Push-Up Anti-Cheat Thresholds (PROVISIONAL, UNCALIBRATED, May 28 2026)
Codex-generated, mirrors Squat pattern. NONE separation-tested yet. Kiet/Khanh own calibration;
interpreter logic changes route through Nam. Ratios are fractions of torsoLen (shoulder-hip distance)
with a pixel floor for close framings.

| Parameter | Value | Catches / notes |
|---|---|---|
| ANGLE_STABLE_GATE (elbow direction gate) | 2 deg | Noise floor for bend/extend direction |
| ROM_GATE (min elbow bend from plank baseline) | 28 deg | Entry gate + partial-rep reject. Proportionally smaller than squat 36, watch in test. |
| PLANK_RETURN_TOLERANCE | 8 deg | Within 8 of personal plank baseline = rep complete |
| PLANK_ANGLE_THRESHOLD (elbow baseline floor) | 155 deg | Fallback top angle until personal baseline captured |
| BOTTOM_ANGLE_RANGE | 80-100 deg | Bottom at elbow <=100. Beginners at ~110 may never trigger, test with weaker user. |
| WRIST_Y_DRIFT_MAX (wall-switch cheat) | 0.22 ratio / 24px min | Catches floor->wall mid-set. May catch fatigue hand-shift. |
| MIN_BODY_TRAVEL (elbow-only cheat) | 0.07 ratio / 8px min | Min shoulder/hip/knee Y travel for rep to count. Live elbow-only uses getChange(stable). |
| MIN_KNEE_TRAVEL (knee-pushup cheat) | 0.28 ratio of shoulder travel / 5px min | Knee must move with body. Plus _kneeMovedThisRep oscillation flag. |
| POSITION_STABLE_GATE (Y getChange gate) | 0.015 ratio / 1.5px min | Stable/moving threshold for shoulder/hip/knee Y |
| START body-line min | 160 deg | Setup straight-body gate |
| START trunk tol / shoulder-wrist-X / shoulder-above-wrist / knee-clearance | 20 / 0.45 / 0.25 / 0.12 | Setup gates (isInStartPosition), tight by design |
| ACTIVE body-line / shoulder-wrist-X / shoulder-above-wrist / knee-clearance | 150 / 0.70 / 0.05 / 0.05 | Looser than setup so fatigue is coached not rejected. ACTIVE shoulder-wrist-X flagged for cut. |
| MAX_REP | 15 | Per-set cap |

## Coaching & Adaptation
| Rule | Value |
|---|---|
| Conservative rep adjustment | heavy = -1, light = +1, medium = unchanged |
| Coach text trend window | 3-5 sets, ups vs downs |
| Praise ladder | 6 tiers (see Report Builder doc) |
| Comparison ladder | 13 tiers, banner never empty |
| Voice cue cadence / cooldowns / priority | Stochastic, no fixed values — see docs/reference/voice-coach/voice-behavior-spec.md (ADD 2026-07-07; supersedes the never-shipped "corrective 3 reps / positive 1 rep" + "5-layer queue") |

Glute Bridge voice pilot tuning (07-08 device-test default; tune on device, shapes locked in
docs/decisions.md). 07-09: cue types renamed (`criticalFault`/`softFault`/`setup`); numbers below unchanged.

| Cue | Value |
|---|---|
| Count | base 0.50, hunger +0.10, cap 1.0, rep 1 always, final 2 reps always, no relief valve |
| Praise | base 0.50, hunger +0.10, cap 0.85, never twice in a row, no formScore probability multiplier |
| Critical fault (`criticalFault`) | base 0.25, persistence +0.30, cap 0.85, first occurrence certain, no relief valve |
| Soft fault (`softFault`) | base 0.20, hunger +0.08, cap 0.55, not first-occurrence deterministic |
| Hustle | off |
| Outcome collision guard | 2nd in-rep outcome cue: `criticalFault` only, different fault, ≥0.5s after previous outcome line's audio ENDS, max 2 voiced outcome cues/rep; the system's only time cooldown |

Timing (07-09 — behavior, not numbers; see decisions.md + voice-coach/realtime-cue-design.html): `criticalFault`
+ `softFault` fire REAL-TIME off `ExerciseBase.liveFaults` the instant a fault is known, not batched at
rep-completion; count + praise stay post-rep. Implemented for glute-bridge scope.

## Active Exercise Screen v8 (May 1, 2026)
Note (05-30): the live form-score ARC was removed (replaced by positive-additive ambient feedback). The
>=75 / 60-74 / <60 thresholds + color tokens below REMAIN the canonical form-score band scheme, now also
used by the transition hero-score banding. Arc-specific dimensions describe the removed element.

| Number | Value | Notes |
|---|---|---|
| Form "good" threshold | >= 75 | Yellow stroke #FFB701 |
| Form "drifting" threshold | 60-74 | Amber-orange stroke #E89A4B |
| Form "fault" threshold | < 60 | Attention stroke #D67B3E |
| Hold-based form score update interval | 1 second | Per-second tick during hold (Type B) |
| Rep-based form score update interval | Per rep completion | Type A only |
| Chart rolling window | ~6-8 seconds | Primary movement angle, not form-score history |
| Post-rep caption duration | 1.9 seconds | Auto-fades |
| Mid-rep caption duration | Until fault clears or rep ends | No fixed timeout |
| Caption max length | ~30 chars target | Soft cap for legibility |
| Rep tally fault encoding | amber outline ring 1.5px | Trigger: repLog.faults.isNotEmpty |
| PT loop dimensions | 80 x 108 px | Top-left, below back + Hiệp pill |
| Form arc dimensions (removed) | 44px circle, 3px stroke | Inline top-right chrome |
| Squat chart reference angles | 90 (parallel target), 110 (shallow cap) | Knee angle plot |
| Plank chart reference angle | 180 (straight body line) | Shoulder-hip-ankle |
| Warrior I chart reference | 90 (front knee target) | |
| Forward Fold chart reference | User's tested ROM target | Per-user, set at onboarding |
| Wall push-up chart references | Lockout angle, depth angle | Elbow angle plot |
| Wall sit chart reference | 90 (knee target) | |

## Session Flow & Transitions (May 25, 2026)
| Number | Value | Notes |
|---|---|---|
| Cinematic transition duration | 5000ms (5s) | Between exercises + before summary. Auto-advance, non-dismissible. |
| Next-exercise auto-start countdown | 30s | Does NOT start until prev-exercise difficulty popup answered. |
| Countdown extender | +30s per tap | "Cần thêm thời gian" secondary CTA |

## Session Form Score (May 31, 2026)
| Number | Value | Notes |
|---|---|---|
| Composite session grade range | 0-105 | session_form_score = form base (0-100) + streak bonus (<=5). DB CHECK 0-105. |
| Raw form base range | 0-100 | raw_form_score, pre-streak. Composite - raw = the streak bonus (no separate column). |
| Streak bonus | +1 per streak day, cap +5 | min(max(streakDays,0),5). Suppressed to 0 when zero scoreable work. |
| Form-score weight | scored units (total_reps for reps, total_seconds for holds) | Collapses to clean-rep % (sum good / sum total). NOT duration. |
| Mixed-modality combine unit | total_sets | Only when a session mixes rep + hold (deferred; none at launch). Launch interim = equal-weight-per-exercise. |
| Hero / ring fill cap | 100 (number shows true value to 105) | Fill clamps at 100; displayed number rides past 100 so streak overflow stays visible. |

## Summary Trophy + Coach (PROVISIONAL, June 2 2026)
Trophy picker (SessionTrophyPicker) + coach builder (SessionCoachBuilder). All provisional, tune from
beta. Designed 06-02.

| Parameter | Value | Notes |
|---|---|---|
| Trophy _pbMargin | 3 | Min points a PB must beat its bar by |
| Trophy _pbFloor | 60 | A record below this isn't trophy-worthy |
| Trophy _streakMilestones | {3, 7, 14, 30} | Exact-match only, not >=. Milestone tier. |
| Trophy _rollingWindow | 5 sessions | Recent-best window. Wiring must feed FULL history oldest-first or the rolling tier collapses into all-time. |
| Trophy _volumeFloor | 30 good reps | Volume tier gate. GOOD reps only. |
| Trophy _solidFloor | 50 | Mid-band floor for the "solid" showed-up fallback |
| Trophy _cleanCut | 85 | NEW threshold, ABOVE the canonical >=75 top band. Clean-session tier. Do not merge with the form-score bands. |
| Coach _gateRate | 0.10 | Gate A: a fault below this rate doesn't surface in the Watch. Rate-based. Affects ONLY the coach. |
| Squat metricCriticalityOrder | depth -> trunk_lean -> heel -> hip_shoulder_sync -> tempo (PLACEHOLDER) | Watch tiebreaker on equal rates. PROVISIONAL, pending doctor validation. |

## Progress Page (June 7, 2026)
Display form score = composite session_form_score (0-105); the milestone "Form" badge is the one
exception, keyed on raw_form_score.

Progressive-reveal gate:
| Number | Value | Notes |
|---|---|---|
| Counts + averages reveal | >= 1 session | |
| Deltas + trend reveal | >= 3 sessions | One policy across gauge, trend chart, weekly-band deltas, Home vitals, ranked-insights qualification. |
| Period delta endpoints | earliest-in-window vs latest-in-window | Store UTC, bucket completed_at via .toLocal() |
| Ranked-insights MIN_FORM_SLOPE | 1.5 (provisional) | Form-tier Theil-Sen slope floor, points/session. Tune from beta. |
| Ranked-insights MIN_FAULT_RATE_SLOPE | 0.03 (provisional) | Fault-tier slope floor on the 0-1 rate scale. Separate floor because fault rate and form points are different scales. |
| Trajectory-line "high" form cutoff | UNSET, Nam to set | Rows 6/7 of the trajectory decision table |

Milestone rail ladder (KỶ LỤC), tier = magnitude within category:
| Category | Silver | Gold | Platinum |
|---|---|---|---|
| Streak (days) | 3, 7 | 14, 30 | 60, 100 |
| Sessions (count) | 1, 5, 10 | 30, 50 | 100 |
| Form (single session, raw_form_score) | 80 | 90 | 100 |
| Consistency | perfect week | perfect month | — |

Streak ladder {3,7,14,30,60,100} is shared with the streak-card footer; extends the trophy
_streakMilestones {3,7,14,30} with 60+100 (trophy tier unchanged). At launch only silver rungs
reachable; locked higher rungs render dimmed. Silver = muted pewter-grey, off the reserved yellow.

Progress gauge trend-direction threshold (06-21): SUPERSEDED 07-02. The gauge no longer renders a
direction/trend chip (confirmed via codebase check). Headline is still the rounded window AVERAGE of
session_form_score for the active period pill; trajectory now lives ONLY in the whole-program ĐƯỜNG
TIẾN BỘ trend chart. Whether kFormTrendSlopeThreshold still computes internally (unused by UI) not
verified.

## Onboarding Fork, Pain->Modality Weights (PROVISIONAL, June 13 2026, doctor-pending)
Feeds the yoga-vs-home fork (fork_recommendation.dart). Positive = yoga lean, negative = home lean;
magnitude 0-1 = signal strength. Multiple pain areas -> the fork takes the max-magnitude one (not a sum).
Pain vocabulary = the canonical 7-zone set (pain_regions.dart). Values already match code. Overwrite on
doctor's correction.

| Region | Weight | Direction | Confidence |
|---|---|---|---|
| lower_back | +0.8 | yoga | med-high |
| shoulder_neck | +0.7 | yoga | medium |
| back | +0.6 | yoga | low-med |
| hip | +0.5 | yoga | medium |
| knee | +0.3 | yoga (mild) | medium |
| ankle | +0.2 | yoga (mild) | low |
| other | +0.1 | yoga (mild) | low |
| wrist | -0.5 | home | low (contrarian, verify) |

Canonical 7-zone pain vocabulary: shoulder_neck, back, lower_back, hip, wrist, knee, ankle, other.

## Onboarding Level Suggestion, Home Fork (June 15, 2026)
Home-fork level. Training duration sets the band; assessment form can only DEGRADE it by one band, never
raise. Supersedes the old home composite for the HOME path only. Yoga path unchanged (0.40 depth / 0.35
comp / 0.25 history, comp gate compScore<0.5 -> cap 0.49, bands >=0.75 advanced / >=0.55 intermediate,
new-user -> beginner). Lives in fitness_test_scoring.dart.

| Parameter | Value | Notes |
|---|---|---|
| Duration buckets | `<6m` / `6m-2y` / `2y+` | VN: < 6 tháng / 6 tháng - 2 năm / 2 năm+. Replaced old <3m/3-11m/1y+. |
| Band from duration | `<6m` -> beginner, `6m-2y` -> intermediate, `2y+` -> advanced | Primary signal. Default/null -> beginner. |
| Form degrade trigger | avg clean-rep % < 40% | Average of squat + wall push-up clean% (good_rep_count / total). Strict <. |
| Degrade effect | drop exactly one band | Degrade-only, floored at beginner. |
| Missing assessment | use the present one; if neither, no degrade | |

## ML Phasing
| Phase | Trigger | Method |
|---|---|---|
| Phase 1 | 0-200 users | Rules-based detection |
| Phase 2 | 200+ sessions | Threshold personalization, fatigue analysis |
| Phase 3 | 500+ sessions | Contextual bandit |
| Feature vector | 53 features | Logged from day 1 |
| Per-rep fatigue analysis | At 200 sessions | Filter Nặng sets, ascending_time inflection |

## Recommendation Engine v4.4 (SHIPPED May 18, 2026)
Source of truth = vika-v44-schema-reference.md + recommendation-engine-v4.3-spec.md.

Plan structure:
| Parameter | Value | Notes |
|---|---|---|
| Plan length | 7 weeks | 2 phases x 3 weeks + 1 deload |
| Phase names | Nền tảng / Phát triển / Phục hồi | Deload = Phục hồi |
| Progression within phase | Linear interp W1 effective start -> tier cap | Approach C |
| Set ramp | 2 -> 3 sets in first ~20% of progression weeks (cap 2 weeks at 2 sets) | Then 3 sets through deload dropping to 2 at 75% peak volume |
| Deload volume | floor(peakTarget x 0.75) | Anchored to peak target = max(effectiveStart, tierRepCap). ~50% reduction from peak. |
| Weekly check-in weeks | W2-W7 | 6 questions, logging only at v1 |
| End-of-plan retest | Forced W8 retest day | Reuses onboarding fitness test logic via FitnessTestScorer.score() |

Two progression mechanisms:
| Mechanism | Trigger | Effect |
|---|---|---|
| Per-exercise variant unlock | Streak = 3 sessions consecutively hitting cap AND avg session difficulty = easy | Swap to harder variant within slot. Mid-plan. |
| Global tier change | End-of-plan retest (W8) | Beginner -> Intermediate -> Advanced. Reshapes whole catalog cap for next plan. |

Stochastic sampling (RETAINED):
| Component | Value |
|---|---|
| Weighted scoring | wGoal=0.45, wLevel=0.25, wPain=0.15, wCooldown=0.15 |
| Epsilon-greedy | eps=0.3, top-3 pool |
| Diversity | MMR (Maximal Marginal Relevance) |
| Session-to-session carry-over | Final set reps/rest as floor for next session (Brookbush autoregulation) |

Exercise catalog calibrated values (SQL ready, not yet applied). Single source of default volume = the
live exercise_catalog table (06-23); ExerciseDefinition no longer carries volume. base_sets added (reps
3, holds 1), not in the per-tier table. This table = the planned per-tier CAP reference.
| Exercise | Base | Beginner cap | Intermediate cap | Advanced cap |
|---|---|---|---|---|
| glute_bridge | 10 reps (was 12) | 15 | 20 | 25 |
| wall_pushup | 10 reps | 15 | 20 | 25 |
| mcgill_curlup | 6 reps | 8 | 10 | 10 (hard ceiling per McGill) |
| squat | 8 reps | 12 | 15 | 20 |
| butterfly | 30s (was 45s) | 45 | 60 | 90 |
| seated_forward_fold | 30s | 45 | 60 | 90 |
| sphinx | 30s | 45 | 60 | 90 |
| standing_forward_fold | 30s | 45 | 60 | 90 |
| cobra | 20s | 30 | 45 | 60 |
| warrior_one | 30s | 45 | 60 | 90 |

Tier adjustments (relative to base): Beginner -2 reps / -10s; Intermediate 0/0; Advanced +2 reps / +10s.

FitnessTestScorer interface (scoring_version="v1"): v1 wraps the 5-rep onboarding assessment; single
swap point for future retest research. Home fork (06-15): duration sets band, then squat + wall push-up
avg clean% < 40% degrades it one band. Yoga fork unchanged.

## Exercise Library
| Item | Count |
|---|---|
| Exercises (Sheet source of truth) | 83 |
| Yoga poses | 43 |
| Total | 126 |
| Yoga YES-FORM | 22 |
| Yoga YES-COUNTING | 15 |
| Yoga GUIDANCE-ONLY | 6 |
| Wall push-up safety metrics | 5 |
| Wall push-up effectiveness | 3 |
| Yoga onboarding | Warrior I (#3), Standing Forward Fold (#9) |

## Voice & TTS
| Item | Value |
|---|---|
| Provider | Viettel AI TTS |
| Free tier | 50,000 chars |
| Voice packs | 4 planned |
| Account creation | Delayed until phrase list finalized |

## Domains & Identifiers
| Item | Value |
|---|---|
| Domain | vikavn.app |
| Package | com.vikavn.app |
| Privacy policy URL | vikavn.app/privacy (Kiet drafting) |
| App name | Vika (Vui Khỏe An Toàn) |
| Release keystore alias | vika |
